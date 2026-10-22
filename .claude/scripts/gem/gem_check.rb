#!/usr/bin/env ruby
# frozen_string_literal: true

# Mechanical gate for a gem that lives in (or was extracted from) a host Rails app: proves the gem stands alone and is packaged
# like a gem. Deterministic, no network, no bundler context needed.
#
#   ruby .claude/scripts/gem/gem_check.rb --gem-dir . [--host-dir .] [--rails-files 'lib/**/engine.rb,lib/**/railtie.rb,lib/generators/**/*,lib/tasks/**/*']
#
# Prints JSON { gem_dir, pass, findings: [{ code, file, line, detail }] }; exit 1 when findings, 2 on usage error.
#
# Codes:
#   GEM_NOT_FOUND            gem dir missing
#   GEMSPEC_MISSING          no *.gemspec in the gem dir
#   GEMSPEC_UNLOADABLE       the gemspec raises when loaded
#   GEMSPEC_FIELD            required metadata missing (name, version, summary, description, authors, license, required_ruby_version, homepage, source_code_uri, changelog_uri)
#   GEMSPEC_FILES            spec.files packages development material (tests, dev kit, docs apps, node_modules, tmp, oracle)
#   GEMSPEC_DEV_MATERIAL     spec.files packages a dev-only Stimulus controller (`_probe_*` parity probes, `theme_panel`): every consumer would pin and register it
#   GEMSPEC_METADATA         a metadata URI (homepage, source_code_uri, changelog_uri, ...) is not a well-formed http(s) URI, or a GitHub changelog_uri/source_code_uri
#                            does not have the shape https://github.com/<owner>/<repo>/(blob|tree)/<ref>/<path>
#                            (a bare https://github.com/<owner>/<repo> is accepted for source_code_uri)
#   GEMSPEC_LICENSE          LICENSE file missing
#   GEM_NOTICES              third-party notices missing for code derived from shadcn/ui, Radix or Lucide (THIRD_PARTY_NOTICES*)
#   GEM_NO_TESTS             no test/ or spec/ directory in the gem
#   GEM_HOST_CONSTANT        Ruby code references a constant that only the host app defines
#   GEM_RAILS_REFERENCE      Rails/ActionView/ActionController/ActiveRecord referenced outside the Rails integration files
#   GEM_UNDECLARED_DEPENDENCY a library namespace is used but the gemspec does not declare its gem
#   GEM_ACTIVESUPPORT_EXT    ActiveSupport core extensions used while activesupport is not a declared dependency and not required
#   GEM_ESCAPES_ROOT         require_relative / File path reaching outside the gem directory, or a host path hard-coded
#
# Comments are removed with Ruby's own lexer (Ripper), so commented-out code neither triggers nor hides findings, and a ` # ` inside a
# string literal is not mistaken for a comment.
#
# Hard-coded host paths are looked for in the lexed string literals, not in the line text: besides `"app/assets/..."` the check sees
# `%w[app/assets/x]` (multi-line lists too), `"#{root}/app/assets/x"`, adjacent / `+` / `<<` / `/` concatenations ("app/" + "assets/x"),
# `File.join("app", "assets", ...)`, `.join("app", "assets")` chains and `%w[app assets].join("/")`. A multi-piece path is reported on the
# line of its first piece, which is where a marker must sit. Not seen: a paren-less `File.join "app", "assets"`. A heredoc body
# whose text starts with a path is flagged and cannot carry a marker (write it as a quoted literal).
# Prose that merely mentions a path (`"edit app/assets/x"`) is not a path. A path the gem builds from its own root (`__dir__`, `root`) is
# indistinguishable from a host path: keep it in the Rails integration files.
#
# Intentional host paths (the one allowlist): a gem file whose job is to INSPECT the host (the doctor) may name a host path
# (`app/assets/...`) when the SAME line carries the marker below as its trailing comment. Nothing else is accepted: a marker
# elsewhere in the file or inside a string does not count. A path inside a multi-line `%w[]` list cannot carry a marker (a `#`
# there is a word), so it is written as quoted literals.
#
#   DEFAULT_CSS = "app/assets/tailwind/application.css" # gem_check:allow GEM_ESCAPES_ROOT -- the doctor reads the host stylesheet
#
#   - exact rule id: only GEM_ESCAPES_ROOT's hard-coded host path check can be allowed (never require_relative leaving the gem,
#     never another code); the id must be written out;
#   - a reason after `--` is required and holds no quotes (a bare marker does not count);
#   - scope: only files matching HOST_PATH_ALLOW_GLOBS (lib/chadcn/doctor/**/*.rb). The Rails integration files
#     (generators, rake tasks, engine, railtie) are already exempt from this check and need no marker. The same literal in any
#     other file keeps failing, marker or not.
#   Decision: dev/decisions/gem-check-host-paths.md

require "json"
require "optparse"
require "ripper"
require "rubygems"
require "uri"

# Files that inspect the host on purpose and may carry a `# gem_check:allow GEM_ESCAPES_ROOT -- <reason>` marker (see header).
HOST_PATH_ALLOW_GLOBS = %w[lib/chadcn/doctor/**/*.rb].freeze
# Matched against the line's TRAILING COMMENT only; the reason holds no quotes, so marker text inside a string literal never counts.
HOST_PATH_ALLOW_MARKER = /\A#\s*gem_check:allow\s+GEM_ESCAPES_ROOT\s+--\s+[^"'\s][^"']*\z/
HOST_PATH_TRAILING_COMMENT = /(?<!\S)#(?![{@$]).*\z/

# Lexer-based view of a Ruby file: the code lines with comments blanked, and the lines of every hard-coded host-path spelling found in
# string literals.
module RubyLex
  HOST_PATH = %r{(?:\A|/|\0)(?:\./)?app/(?:assets|javascript|views|components)(?:/|\z)}
  # What may sit between two string pieces that still form one path, and the separator it stands for.
  JOINERS = { [] => "", [ "," ] => "/", [ "+" ] => "", [ "<<" ] => "", [ "/" ] => "/", [ ")", "/" ] => "/", [ ")", ".", "join", "(" ] => "/" }.freeze
  IGNORED = %i[on_sp on_ignored_nl on_ignored_sp on_comment].freeze
  WORD_LISTS = %i[on_words_beg on_qwords_beg on_symbols_beg on_qsymbols_beg].freeze
  OPENERS = (WORD_LISTS + %i[on_tstring_beg on_backtick on_regexp_beg]).freeze
  CLOSERS = %i[on_tstring_end on_regexp_end on_label_end].freeze

  module_function

  # => [[[number, comment-free text]], [line of a hard-coded host path], { line => its real comment }]
  def scan(source)
    lines = source.lines(chomp: true)
    tokens = Ripper.lex(source)
    strip_comments(lines, tokens)
    comments = tokens.select { |_, type, _| type == :on_comment }.to_h { |(line, _), _, str, _| [ line, str.chomp ] }
    [ lines.each_with_index.map { |text, i| [ i + 1, text ] }, host_path_lines(tokens).uniq, comments ]
  end

  def strip_comments(lines, tokens)
    tokens.each do |(line, col), type, _|
      case type
      when :on_comment then lines[line - 1] = lines[line - 1].byteslice(0, col).to_s.scrub
      when :on_embdoc_beg, :on_embdoc, :on_embdoc_end then lines[line - 1] = ""
      end
    end
  end

  # String literals as { text, line, from, to (token indexes), chain (may be joined to its neighbours), list (a %w list as one path) };
  # an interpolation becomes "\0".
  def literals(tokens)
    stack = []
    found = []
    skip = false
    tokens.each_with_index do |((line, _), type, str, _), i|
      if skip
        skip = false
        next
      end
      case type
      when *OPENERS then stack << open_unit(type, line, i, stack)
      when :on_symbeg then stack << open_unit(:on_tstring_beg, line, i, stack) unless str == ":"
      when :on_embexpr_beg then stack << { kind: :expr }
      when :on_embexpr_end then interpolate(stack.tap(&:pop))
      when :on_embvar then skip = interpolate(stack) || true
      when :on_words_sep then start_word(stack.last)
      when :on_tstring_content
        if stack.last&.key?(:words)
          stack.last[:words].last << str
          stack.last[:lines][-1] ||= line
        else
          found << { text: str, line: line, from: i, to: i }
        end
      when *CLOSERS then close(stack, found, i, type)
      end
    end
    found
  end

  def start_word(unit)
    return unless unit&.key?(:words)

    unit[:words] << +""
    unit[:lines] << nil
  end

  def interpolate(stack)
    stack.last&.fetch(:words, nil)&.last&.<<("\0")
  end

  # `parent` is the token index of the enclosing literal (nil at top level): only siblings join each other.
  def open_unit(kind, line, from, stack)
    parent = stack.reverse_each.find { |u| u.key?(:words) }
    { kind: kind, line: line, from: from, words: [ +"" ], lines: [ nil ], parent: parent && parent[:from] }
  end

  def close(stack, found, index, closer)
    unit = stack.pop
    return unless unit&.key?(:words) && unit[:kind] != :on_regexp_beg

    at = { line: unit[:line], from: unit[:from], to: index, parent: unit[:parent] }
    words = unit[:words]
    if WORD_LISTS.include?(unit[:kind])
      words.zip(unit[:lines]).reject { |word, _| word.empty? }.each { |word, line| found << at.merge(text: word, line: line || unit[:line]) }
      found << at.merge(text: words.reject(&:empty?).join("/"), list: true)
    else
      found << at.merge(text: words.last, chain: closer != :on_label_end) # a hash label key never starts a concatenation
    end
  end

  # token index => true when the token sits directly inside the parentheses of a `join(` call (File.join, Pathname#join, Array#join)
  def join_arguments(tokens, sig)
    owners = []
    prev = nil
    sig.each_with_object({}) do |i, inside|
      type = tokens[i][1]
      owners.pop if type == :on_rparen
      inside[i] = owners.last == true
      owners << (!prev.nil? && tokens[prev][1] == :on_ident && tokens[prev][2] == "join") if type == :on_lparen
      prev = i
    end
  end

  # The token stream with its significant (non-space, non-comment) tokens indexed, so neighbours can be asked cheaply.
  View = Struct.new(:tokens, :sig, :inside_join) do
    def self.of(tokens)
      sig = tokens.each_index.reject { |i| IGNORED.include?(tokens[i][1]) }
      new(tokens, sig, RubyLex.join_arguments(tokens, sig))
    end

    # Position in `sig` of the first significant token after a token index.
    def after(index) = sig.bsearch_index { |i| i > index } || sig.size

    # The significant tokens strictly between two token indexes.
    def between(from, to) = sig[after(from)...(sig.bsearch_index { |i| i >= to } || sig.size)] || []

    def texts(indexes) = indexes.map { |i| tokens[i][2] }

    # A load path is not a file read on the host: `require "x"` / `require_relative("x")` arguments are judged by the escape check.
    def require_argument?(lit)
      k = (sig.bsearch_index { |i| i >= lit[:from] } || sig.size) - 1
      k -= 1 if k >= 0 && tokens[sig[k]][1] == :on_lparen
      k >= 0 && tokens[sig[k]][1] == :on_ident && %w[require require_relative].include?(tokens[sig[k]][2])
    end

    def followed_by_join?(lit) = texts(sig[after(lit[:to]), 2]) == %w[. join]

    # What joins two neighbouring literals into one path ("" or "/"), nil when they are not joined.
    def separator(a, b)
      indexes = between(a[:to], b[:from])
      key = texts(indexes)
      JOINERS[key] if JOINERS.key?(key) && (key != [ "," ] || inside_join[indexes.first])
    end
  end

  def host_path_lines(tokens)
    view = View.of(tokens)
    lits = literals(tokens).sort_by { |l| [ l[:from], l[:to] ] }.reject { |l| view.require_argument?(l) }
    single_hits(lits) + list_join_hits(view, lits) + chain_hits(view, lits)
  end

  def single_hits(lits) = lits.select { |l| !l[:list] && l[:text].match?(HOST_PATH) }.map { |l| l[:line] }

  # `%w[app assets].join("/")` is one path; a bare %w list is only its words.
  def list_join_hits(view, lits)
    lits.select { |l| l[:list] && l[:text].match?(HOST_PATH) && view.followed_by_join?(l) }.map { |l| l[:line] }
  end

  # Literals join only with siblings of the same enclosing literal: never with the outer string's neighbours, but with each other.
  def chain_hits(view, lits)
    lits.select { |l| l[:chain] }.group_by { |l| l[:parent] }.values.flat_map do |siblings|
      siblings.chunk_while { |a, b| b[:from] > a[:to] && view.separator(a, b) }.filter_map do |chain|
        chain.first[:line] if chain.size > 1 && joined_text(view, chain).match?(HOST_PATH)
      end
    end
  end

  def joined_text(view, chain)
    chain.each_cons(2).reduce(chain.first[:text]) { |text, (a, b)| text + view.separator(a, b) + b[:text] }
  end
end

opts = { host_dir: ".", rails_files: %w[lib/**/engine.rb lib/**/railtie.rb lib/generators/**/* lib/tasks/**/*] }
OptionParser.new do |o|
  o.on("--gem-dir DIR") { |v| opts[:gem_dir] = v }
  o.on("--host-dir DIR") { |v| opts[:host_dir] = v }
  o.on("--rails-files LIST") { |v| opts[:rails_files] = v.split(",") }
end.parse!
abort("usage: --gem-dir DIR [--host-dir DIR]") unless opts[:gem_dir]

gem_dir = File.expand_path(opts[:gem_dir])
host_dir = File.expand_path(opts[:host_dir])
findings = []
add = ->(code, file, line, detail) { findings << { code: code, file: file && file.delete_prefix("#{gem_dir}/"), line: line, detail: detail } }
finish = lambda do |code|
  puts JSON.pretty_generate(gem_dir: opts[:gem_dir], pass: findings.empty?, findings: findings)
  exit(code)
end

unless Dir.exist?(gem_dir)
  add.call("GEM_NOT_FOUND", nil, nil, gem_dir)
  finish.call(1)
end

# ---- gemspec ----------------------------------------------------------------------------------------------------
specs = Dir[File.join(gem_dir, "*.gemspec")]
spec = nil
if specs.empty?
  add.call("GEMSPEC_MISSING", nil, nil, "no *.gemspec in #{opts[:gem_dir]}")
else
  begin
    Dir.chdir(gem_dir) { spec = Gem::Specification.load(specs.first) }
    add.call("GEMSPEC_UNLOADABLE", specs.first, nil, "Gem::Specification.load returned nil (see `ruby -e 'p Gem::Specification.load(\"#{specs.first}\")'`)") unless spec
  rescue StandardError, ScriptError => e
    add.call("GEMSPEC_UNLOADABLE", specs.first, nil, "#{e.class}: #{e.message}")
  end
end

DEV_MATERIAL = %r{\A(?:test|spec|dev|doc|docs(?!/[^/]+\.md\z)|oracle|node_modules|tmp|react-[\w-]+|\.github|\.claude|\.ai|bin/ci|Gemfile\.lock)(?:/|\z)}
REQUIRED_METADATA = %w[source_code_uri changelog_uri].freeze
# Stimulus controllers that exist only for the dev kit's parity harness and demo pages.
DEV_CONTROLLER = %r{(?:\A|/)(?:_probe_[^/]*|theme_panel_controller\.js)\z}
GITHUB_URI = %r{\Ahttps://github\.com/[\w.-]+/[\w.-]+/(?:blob|tree)/[\w.-]+/\S+\z}
# A bare repository URI is a valid source_code_uri for a gem that sits at the root of its own repository.
GITHUB_REPO = %r{\Ahttps://github\.com/[\w.-]+/[\w.-]+/?\z}
# A second /tree|blob/<ref>/ after the first, adjacent or not (`#{homepage}/blob/main/...` appended to a tree/ homepage).
DOUBLE_REF = %r{/(?:tree|blob)/[^/]+/(?:.*/)?(?:tree|blob)/}

if spec
  { "name" => spec.name, "version" => spec.version.to_s, "summary" => spec.summary, "description" => spec.description, "authors" => spec.authors,
    "license" => spec.licenses, "homepage" => spec.homepage }.each do |field, value|
    add.call("GEMSPEC_FIELD", specs.first, nil, "#{field} is missing or empty") if value.nil? || (value.respond_to?(:empty?) && value.empty?) || value.to_s == "0"
  end
  add.call("GEMSPEC_FIELD", specs.first, nil, "required_ruby_version is not set (it defaults to >= 0)") if spec.required_ruby_version.to_s == ">= 0"
  REQUIRED_METADATA.each { |m| add.call("GEMSPEC_FIELD", specs.first, nil, "metadata[#{m}] is missing") unless spec.metadata[m] }
  packaged = spec.files.select { |f| f.match?(DEV_MATERIAL) }
  add.call("GEMSPEC_FILES", specs.first, nil, "packages development material: #{packaged.first(6).join(', ')}#{packaged.size > 6 ? ' ...' : ''}") if packaged.any?
  dev_controllers = spec.files.select { |f| f.match?(DEV_CONTROLLER) }
  add.call("GEMSPEC_DEV_MATERIAL", specs.first, nil, "packages dev-only controllers: #{dev_controllers.first(4).join(', ')}#{dev_controllers.size > 4 ? ' ...' : ''}") if dev_controllers.any?
  { "homepage" => spec.homepage }.merge(spec.metadata.select { |key, _| key.end_with?("_uri") }).each do |field, value|
    uri = begin
      URI.parse(value.to_s)
    rescue URI::InvalidURIError
      nil
    end
    well_formed = uri.is_a?(URI::HTTP) && uri.host && !uri.host.empty?
    add.call("GEMSPEC_METADATA", specs.first, nil, "#{field} is not a well-formed http(s) URI: #{value.inspect}") unless well_formed || value.to_s.empty?
    next unless well_formed && uri.host == "github.com" && %w[source_code_uri changelog_uri].include?(field)

    shaped = (value.match?(GITHUB_URI) && !value.match?(DOUBLE_REF)) || (field == "source_code_uri" && value.match?(GITHUB_REPO))
    add.call("GEMSPEC_METADATA", specs.first, nil, "#{field} #{value} does not have the shape https://github.com/<owner>/<repo>/(blob|tree)/<ref>/<path>") unless shaped
  end
end
add.call("GEMSPEC_LICENSE", nil, nil, "no LICENSE / LICENSE.txt / MIT-LICENSE") if Dir[File.join(gem_dir, "{LICENSE,LICENSE.*,MIT-LICENSE,COPYING}")].empty?
add.call("GEM_NO_TESTS", nil, nil, "no test/ or spec/ directory") unless Dir.exist?(File.join(gem_dir, "test")) || Dir.exist?(File.join(gem_dir, "spec"))

# ---- Ruby sources ------------------------------------------------------------------------------------------------
lib_files = Dir[File.join(gem_dir, "{lib,app}/**/*.rb")]
rails_glob = opts[:rails_files].flat_map { |g| Dir[File.join(gem_dir, g)] }.select { |f| File.file?(f) }
# Comments are blanked by the lexer; `host_paths` holds, per file, the lines that spell a hard-coded host path.
scans = lib_files.to_h { |f| [ f, RubyLex.scan(File.read(f).scrub) ] }
sources = scans.transform_values(&:first)
host_paths = scans.transform_values { |scan| scan[1] }
real_comments = scans.transform_values(&:last)
host_path_allowed_files = HOST_PATH_ALLOW_GLOBS.flat_map { |g| Dir[File.join(gem_dir, g)] }
host_path_marked_lines = lambda do |file|
  next [] unless host_path_allowed_files.include?(file)

  # Both views must agree: the line's first ` #` text is the marker AND the lexer sees it as a real comment (a `#` inside %w[] is a word).
  File.readlines(file, chomp: true).each_with_index.filter_map do |l, i|
    i + 1 if l[HOST_PATH_TRAILING_COMMENT]&.match?(HOST_PATH_ALLOW_MARKER) && real_comments[file][i + 1]&.match?(HOST_PATH_ALLOW_MARKER)
  end
end
all_code = sources.values.flatten(1).map(&:last).join("\n")
# Mentions count for provenance even inside a comment ("ported from Radix"): the notice requirement reads the raw text.
raw_code = lib_files.map { |f| File.read(f).scrub }.join

# Third-party code notices: required as soon as the gem ships things derived from these projects.
derived = { "shadcn/ui" => /shadcn/i, "Radix" => /radix/i, "Lucide" => /lucide/i }.select { |_, re| raw_code.match?(re) }
notices = Dir[File.join(gem_dir, "THIRD_PARTY_NOTICES*")].map { |f| File.read(f) }.join("\n")
derived.each_key do |name|
  add.call("GEM_NOTICES", nil, nil, "code derived from #{name} but no mention in THIRD_PARTY_NOTICES") unless notices.match?(/#{Regexp.escape(name)}/i)
end

# Host constants: top-level namespaces declared in the host's own app/ and lib/ that the gem does not declare itself.
# Host: only TOP-LEVEL declarations count (column 0); a nested `class Accordion` inside the host's namespace is not reachable from the gem.
# Gem: any declaration counts, so a name the gem defines itself is trusted to resolve lexically.
host_top_level = ->(files) { files.flat_map { |f| File.read(f).scan(/^(?:class|module)\s+([A-Z]\w*)/).flatten }.uniq }
declared_anywhere = ->(files) { files.flat_map { |f| File.read(f).scan(/^\s*(?:class|module)\s+([A-Z]\w*)/).flatten }.uniq }
host_files = Dir[File.join(host_dir, "{app,lib}/**/*.rb")].reject { |f| f.start_with?("#{gem_dir}/") }
generic = %w[Rails ActiveSupport ActionView ActionController ActiveRecord ActiveModel Phlex Kernel Object Module Class Struct Data Set JSON Time Date String Symbol Hash Array Comparable Enumerable]
host_constants = host_top_level.call(host_files) - declared_anywhere.call(Dir[File.join(gem_dir, "**/*.rb")]) - generic

sources.each do |file, lines|
  marked = host_path_marked_lines.call(file)
  lines.each do |n, text|
    host_constants.each do |const|
      add.call("GEM_HOST_CONSTANT", file, n, "references #{const}, defined by the host app") if text.match?(/(?<![\w:])#{const}(?:::|\.\w)/)
    end
    if (rel = text[/require_relative\s+["']((?:\.\.\/)+)/, 1])
      depth = File.dirname(file.delete_prefix("#{gem_dir}/")).split("/").reject { |part| part == "." }.size
      add.call("GEM_ESCAPES_ROOT", file, n, "require_relative leaves the gem directory (#{rel.scan('../').size} levels up from depth #{depth})") if rel.scan("../").size > depth
    end
    hard_coded = text.match?(%r{["'](?:\./)?app/(?:assets|javascript|views|components)/}) || host_paths[file].include?(n)
    exempt = rails_glob.include?(file) || marked.include?(n)
    add.call("GEM_ESCAPES_ROOT", file, n, "hard-coded host path (app/... or Rails.root); only doctor files may allow it, with `# gem_check:allow GEM_ESCAPES_ROOT -- <reason>` on the same line") if hard_coded && !exempt
  end
end

# Rails / ActiveSupport use outside the integration layer.
rails_re = /(?<![\w:])(?:Rails|ActionView|ActionController|ActiveRecord|ActionDispatch)\b/
# `defined?(Rails::Engine)` (R2: the engine is loaded only when Rails is there) probes for Rails, it does not depend on it.
rails_guard = /\bdefined\?\(\s*Rails(?:::\w+)*\s*\)/
sources.each do |file, lines|
  next if rails_glob.include?(file)

  lines.each { |n, text| add.call("GEM_RAILS_REFERENCE", file, n, "#{text[rails_re]} used outside the Rails integration files (engine/railtie/generators/tasks)") if text.gsub(rails_guard, "").match?(rails_re) }
end

runtime = spec ? spec.runtime_dependencies.map(&:name) : []
# Library namespaces and the gem that provides them (only phlex's own classes count: Phlex::HTML/SGML/Kit/Helpers, so a
# third-party namespace nested under Phlex is not a use of phlex).
USES = {
  "activesupport" => /(?<![\w:])ActiveSupport(?:::|\.)/,
  "tailwind_merge" => /(?<![\w:])TailwindMerge(?:::|\.)/,
  "zeitwerk" => /(?<![\w:])Zeitwerk(?:::|\.)/,
  "phlex" => /(?<![\w:])Phlex::(?:HTML|SGML|Kit|Helpers)\b/,
  "phlex-rails" => /(?<![\w:])Phlex::Rails\b/
}.freeze
if spec
  USES.each do |dep, re|
    next if runtime.include?(dep) || (dep == "phlex" && runtime.include?("phlex-rails"))

    hit = sources.find { |f, lines| !rails_glob.include?(f) && lines.any? { |_, t| t.match?(re) } }
    add.call("GEM_UNDECLARED_DEPENDENCY", hit[0], nil, "#{dep} is used but the gemspec has no runtime dependency on it") if hit
  end
end

EXT = /\.(?:deep_merge|presence|present\?|blank\?|underscore|dasherize|camelize|titleize|html_safe|squish|except|slice!?|to_sentence|with_indifferent_access|symbolize_keys|stringify_keys|try|in\?)\b/
require_as = all_code.match?(/require\s+["']active_support/)
unless runtime.include?("activesupport") || require_as
  uses = sources.flat_map { |f, lines| lines.filter_map { |n, t| [ f, n, t[EXT] ] if t.match?(EXT) && !t.match?(/\.except\(/) } }
  uses.first(3).each { |f, n, ext| add.call("GEM_ACTIVESUPPORT_EXT", f, n, "#{ext} is an ActiveSupport extension; declare activesupport or use plain Ruby") }
  add.call("GEM_ACTIVESUPPORT_EXT", nil, nil, "#{uses.size} ActiveSupport extension call(s) in total") if uses.size > 3
end

finish.call(findings.empty? ? 0 : 1)

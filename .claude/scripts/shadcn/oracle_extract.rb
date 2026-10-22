#!/usr/bin/env ruby
# frozen_string_literal: true

# Oracle extractor for the shadcn -> Phlex port.
#
# Fetches the official shadcn registry source for every `registry:ui` item (or a
# subset) and derives a machine-readable manifest per component plus a
# dependency-wave graph. Pure Ruby stdlib, no LLM, deterministic.
#
#   ruby .claude/scripts/shadcn/oracle_extract.rb                       # all components
#   ruby .claude/scripts/shadcn/oracle_extract.rb --only button,dialog  # subset
#   ruby .claude/scripts/shadcn/oracle_extract.rb --offline             # use cached registry/*.json only
#   ruby .claude/scripts/shadcn/oracle_extract.rb --list                # print names and exit
#   ruby .claude/scripts/shadcn/oracle_extract.rb --verify-catalog <catalog dir>/src/components/ui
#                                                                       # G0: catalog files must equal the oracle (tokens, slots, cva, parts)
#
# Output (default <port dir>/oracle/):
#   registry/<name>.json   raw registry item (cache; also the golden fixtures)
#   src/<name>.tsx         primary React source, verbatim
#   manifest/<name>.json   parts, data-slots, cva variants, class tokens, props, deps, tier
#   graph.json             nodes + dependency waves
#   VERSION.json           style, fetched_at, source digest

require_relative "layout"
require "json"
require "net/http"
require "uri"
require "digest"
require "fileutils"
require "optparse"
require "time"

module ShadcnOracle
  BASE = "https://ui.shadcn.com/r"
  OVERLAY_PRIMITIVES = %w[Dialog AlertDialog Popover Tooltip HoverCard DropdownMenu ContextMenu Menubar Select NavigationMenu].freeze
  # Radix parts that render NO element of their own (context providers / portals). shadcn still writes data-slot on them, but the
  # attribute is dropped by Radix, so it never reaches the DOM: a port must not render it (G2) and G1 must not require it.
  NO_DOM = /\A(?:(?:Dialog|Sheet|AlertDialog|DropdownMenu|ContextMenu|Popover|Tooltip|HoverCard|Select)Primitive\.(?:Root|Sub|Provider)|MenubarPrimitive\.(?:Menu|Sub)|\w+Primitive\.Portal)\z/
  THIRD_PARTY = {
    "cmdk" => "cmdk", "sonner" => "sonner", "embla-carousel-react" => "embla", "react-day-picker" => "react-day-picker",
    "recharts" => "recharts", "input-otp" => "input-otp", "react-resizable-panels" => "resizable-panels",
    "vaul" => "vaul", "react-hook-form" => "react-hook-form", "next-themes" => "next-themes",
    "@base-ui/react" => "base-ui", "@shadcn/react" => "@shadcn/react"
  }.freeze

  # Parses the subset of JS object literals that appear inside `cva(...)`.
  class LiteralParser
    def initialize(src)
      @s = src
      @i = 0
    end

    def parse_value
      skip_ws
      case @s[@i]
      when "{" then parse_object
      when "[" then parse_array
      when '"', "'", "`" then parse_string
      else parse_bare
      end
    end

    def parse_args(count)
      Array.new(count) do
        value = parse_value
        skip_ws
        @i += 1 if @s[@i] == ","
        value
      end
    end

    private

    def skip_ws
      loop do
        if @s[@i] =~ /\s/ then @i += 1
        elsif @s[@i, 2] == "//" then @i = @s.index("\n", @i) || @s.size
        elsif @s[@i, 2] == "/*" then @i = (@s.index("*/", @i) || @s.size) + 2
        else break
        end
      end
    end

    def parse_object
      @i += 1
      hash = {}
      loop do
        skip_ws
        (@i += 1) && break if @s[@i] == "}" || @i >= @s.size
        key = @s[@i] =~ /["']/ ? parse_string : parse_bare
        skip_ws
        @i += 1 if @s[@i] == ":"
        hash[key] = parse_value
        skip_ws
        @i += 1 if @s[@i] == ","
      end
      hash
    end

    def parse_array
      @i += 1
      list = []
      loop do
        skip_ws
        (@i += 1) && break if @s[@i] == "]" || @i >= @s.size
        list << parse_value
        skip_ws
        @i += 1 if @s[@i] == ","
      end
      list
    end

    def parse_string
      quote = @s[@i]
      @i += 1
      out = +""
      while @i < @s.size && @s[@i] != quote
        if @s[@i] == "\\" then out << @s[@i + 1].to_s && @i += 2
        else (out << @s[@i]) && @i += 1
        end
      end
      @i += 1
      out
    end

    def parse_bare
      start = @i
      @i += 1 while @i < @s.size && @s[@i] !~ /[,}\]:\s]/
      @s[start...@i]
    end
  end

  module Scan
    module_function

    # Index of the character matching the opener at `open_idx`, skipping strings.
    def balanced(src, open_idx)
      pairs = { "(" => ")", "{" => "}", "[" => "]" }
      opener = src[open_idx]
      closer = pairs.fetch(opener)
      depth = 0
      i = open_idx
      while i < src.size
        ch = src[i]
        if ch == '"' || ch == "'" || ch == "`"
          i += 1
          i += (src[i] == "\\" ? 2 : 1) while i < src.size && src[i] != ch
        elsif ch == opener then depth += 1
        elsif ch == closer
          depth -= 1
          return i if depth.zero?
        end
        i += 1
      end
      src.size - 1
    end

    def string_literals(text)
      text.scan(/"((?:[^"\\]|\\.)*)"|'((?:[^'\\]|\\.)*)'|`((?:[^`\\]|\\.)*)`/).map { |m| m.compact.first }
    end

    def tokens(strings)
      strings.flat_map { |s| s.split(/\s+/) }.reject(&:empty?)
    end
  end

  class Component
    attr_reader :name, :raw, :source

    def initialize(name, raw)
      @name = name
      @raw = raw
      @source = primary_file.fetch("content")
    end

    def primary_file
      raw.fetch("files").find { |f| f["path"].end_with?("/ui/#{name}.tsx") } || raw.fetch("files").first
    end

    def manifest
      imports = parse_imports
      parts = parse_parts
      cva = parse_cva
      all_tokens = (parts.flat_map { |p| p[:class_tokens] } + cva.values.flat_map { |c| c[:tokens] }).uniq.sort
      {
        name: name,
        style: "new-york-v4",
        source_sha: Digest::SHA256.hexdigest(source)[0, 16],
        use_client: source.lstrip.start_with?('"use client"'),
        tier: tier(imports, parts),
        exports: parse_exports,
        parts: parts,
        cva: cva,
        class_tokens: all_tokens,
        data_attrs: parts.flat_map { |p| p[:data_attrs].map { |a| a[:name] } }.uniq.sort,
        data_slots: parts.flat_map { |p| p[:data_slots] }.uniq.sort,
        non_rendered_slots: parts.flat_map { |p| p[:slot_tags].select { |_, tag| tag.match?(NO_DOM) }.keys }.uniq.sort,
        radix_primitives: radix_primitives(imports),
        third_party: imports.filter_map { |i| third_party_for(i[:from]) }.uniq,
        icons: imports.select { |i| i[:from] == "lucide-react" }.flat_map { |i| i[:names] }.sort,
        text_literals: source.scan(/>\s*([A-Za-z][^<>{}\n]*?)\s*<\//).flatten.uniq,
        registry_dependencies: imports.filter_map { |i| i[:from][%r{/ui/([\w-]+)\z}, 1] }.uniq.sort - [name],
        hooks: imports.filter_map { |i| i[:from][%r{/hooks/([\w-]+)\z}, 1] }.uniq.sort,
        npm_dependencies: raw.fetch("dependencies", []).sort,
        extra_files: raw.fetch("files").map { |f| f["path"] } - [primary_file["path"]]
      }
    end

    private

    # "@shadcn/react/message-scroller" belongs to "@shadcn/react": match the package and its subpaths.
    def third_party_for(from)
      THIRD_PARTY.each { |pkg, label| return label if from == pkg || from.start_with?("#{pkg}/") }
      nil
    end

    def parse_imports
      source.scan(/^import\s+(.*?)\s+from\s+"([^"]+)"/m).map do |clause, from|
        names = clause.scan(/\{([^}]*)\}/).flatten.flat_map { |g| g.split(",") }.map { |n| n.strip.split(/\s+as\s+/).first.to_s }.reject(&:empty?)
        { from: from, names: names, clause: clause.strip }
      end
    end

    def radix_primitives(imports)
      imports.select { |i| i[:from] == "radix-ui" || i[:from].start_with?("@radix-ui/") }
             .flat_map { |i| i[:names] }.uniq.sort
    end

    def tier(imports, parts)
      return :third_party if imports.any? { |i| third_party_for(i[:from]) }

      prims = radix_primitives(imports) - %w[Slot Label Separator AspectRatio]
      return :overlay if (prims & OVERLAY_PRIMITIVES).any?
      return :radix_stateful if prims.any? || parts.any? { |p| p[:wraps].to_s.match?(/Primitive/) }

      source.include?("useState") || source.include?("useEffect") ? :client : :static
    end

    def parse_exports
      block = source[/^export\s*\{([^}]*)\}/m, 1].to_s
      names = block.split(",").map(&:strip).reject(&:empty?)
      names += source.scan(/^export\s+(?:async\s+)?function\s+(\w+)/).flatten
      names += source.scan(/^export\s+const\s+(\w+)/).flatten
      names.uniq
    end

    def parse_cva
      out = {}
      source.to_enum(:scan, /const\s+(\w+)\s*=\s*cva\(/).each do
        m = Regexp.last_match
        open_idx = m.end(0) - 1
        close_idx = Scan.balanced(source, open_idx)
        base, opts = begin
          LiteralParser.new(source[(open_idx + 1)...close_idx]).parse_args(2)
        rescue StandardError
          [nil, {}]
        end
        variants = opts.is_a?(Hash) ? opts.fetch("variants", {}) : {}
        out[m[1]] = {
          base: base.is_a?(String) ? base : nil,
          variants: variants,
          defaults: opts.is_a?(Hash) ? opts.fetch("defaultVariants", {}) : {},
          compound: opts.is_a?(Hash) ? opts.fetch("compoundVariants", []) : [],
          tokens: Scan.tokens(Scan.string_literals(source[(open_idx + 1)...close_idx]).reject { |s| s.match?(/\A(variants|defaultVariants)\z/) }).uniq.sort
        }
      end
      out
    end

    def parse_parts
      # Components are `function Name(` (almost all) or `const Name = (` arrow functions (sonner, chart).
      starts = source.to_enum(:scan, /^(?:function\s+(\w+)\s*(?:<[^>]*>)?\(|const\s+([A-Z]\w*)\s*=\s*(?:async\s*)?\()/).map { Regexp.last_match }
      starts.each_with_index.map do |m, idx|
        stop = idx + 1 < starts.size ? starts[idx + 1].begin(0) : source.size
        body = source[m.begin(0)...stop]
        sig_end = Scan.balanced(body, body.index("("))
        signature = body[0..sig_end]
        {
          name: m[1] || m[2],
          data_attrs: body.scan(/\b(data-(?!slot\b)[\w-]+)=(?:"([^"]*)"|\{([^}]*)\})/).map { |n, lit, expr| { name: n, value: lit || "{#{expr}}" } }.uniq,
          data_slots: body.scan(/data-slot=(?:"([^"]+)"|\{"([^"]+)"\})/).flatten.compact.uniq,
          data_slot: body[/data-slot=(?:"([^"]+)"|\{"([^"]+)"\})/, 1] || body[/data-slot=\{"([^"]+)"\}/, 1],
          wraps: body[/<(\w+Primitive\.\w+|Slot\.Root|Slot|Comp|\w+\.Root)\b/, 1],
          renders: body[/return\s*\(?\s*<(\w[\w.]*)/, 1],
          # the element that carries each data-slot (a part may wrap its Content in a Portal: the slot is on the inner tag)
          slot_tags: body.scan(/<([A-Z][\w.]*)\b[^<]*?data-slot=(?:"([^"]+)"|\{"([^"]+)"\})/m).to_h { |tag, a, b| [a || b, tag] },
          props: parse_props(signature),
          class_tokens: Scan.tokens(class_strings(body)).uniq.sort,
          uses_cva: body.match?(/\w+Variants\(/),
          variants_used: body.scan(/(\w+Variants)\(/).flatten.uniq
        }
      end
    end

    def class_strings(body)
      strings = []
      body.to_enum(:scan, /\bcn\(/).each do
        open_idx = Regexp.last_match.end(0) - 1
        strings.concat(Scan.string_literals(body[open_idx..Scan.balanced(body, open_idx)]))
      end
      strings.concat(body.scan(/className=(?:"([^"]*)"|\{"([^"]*)"\})/).flatten.compact)
      strings
    end

    def parse_props(signature)
      destructure = signature[/\(\s*\{(.*?)\}\s*:/m, 1].to_s
      destructured = destructure.split(/,(?![^()]*\))/).map(&:strip).reject(&:empty?).map do |entry|
        next { name: "...props", rest: true } if entry.start_with?("...")

        name, default = entry.split(/\s*=\s*/, 2)
        { name: name, default: default }.compact
      end
      typed = signature.scan(/(\w+)\??:\s*([^;\n}]+?)(?=\s*(?:[;\n}]|\z))/).map { |n, t| { name: n, type: t.strip } }
      { destructured: destructured, typed: typed.reject { |t| %w[React className].include?(t[:name]) } }
    end
  end

  class Runner
    def initialize(opts)
      @opts = opts
      @out = opts[:out]
    end

    def run
      return verify_catalog(@opts[:verify_catalog]) if @opts[:verify_catalog]

      names = opts_names
      return puts(names) if @opts[:list]

      %w[registry src manifest].each { |d| FileUtils.mkdir_p(File.join(@out, d)) }
      manifests = names.filter_map { |n| build(n) }
      write_graph(manifests)
      File.write(File.join(@out, "VERSION.json"), JSON.pretty_generate(
        style: @opts[:style], fetched_at: Time.now.utc.iso8601, components: manifests.size,
        digest: Digest::SHA256.hexdigest(manifests.map { |m| m[:source_sha] }.join)[0, 16]
      ))
      warn "oracle: #{manifests.size} components -> #{@out}"
    end

    def verify_catalog(dir)
      problems = []
      Dir[File.join(@out, "manifest", "*.json")].sort.each do |mf|
        want = JSON.parse(File.read(mf))
        file = File.join(dir, "#{want['name']}.tsx")
        next problems << { component: want["name"], code: "G0_CATALOG_MISSING", detail: file } unless File.exist?(file)

        raw = { "files" => [{ "path" => "ui/#{want['name']}.tsx", "content" => File.read(file) }], "dependencies" => [] }
        got = JSON.parse(JSON.generate(Component.new(want["name"], raw).manifest))
        %w[class_tokens data_slots exports].each do |key|
          next if got[key] == want[key]

          problems << { component: want["name"], code: "G0_CATALOG_DRIFT", detail: "#{key}: only oracle #{(want[key] - got[key]).first(5)} only catalog #{(got[key] - want[key]).first(5)}" }
        end
        problems << { component: want["name"], code: "G0_CATALOG_DRIFT", detail: "cva variants differ" } if got["cva"].transform_values { |c| c["variants"] } != want["cva"].transform_values { |c| c["variants"] }
      end
      puts JSON.pretty_generate(pass: problems.empty?, problems: problems)
      exit(problems.empty? ? 0 : 1)
    end

    private

    def opts_names
      return @opts[:only] if @opts[:only]&.any?

      index = @opts[:offline] ? cached_names : JSON.parse(http_get("#{BASE}/index.json"))
      return index if index.first.is_a?(String)

      index.select { |i| i["type"] == "registry:ui" }.map { |i| i["name"] }
    end

    def cached_names
      Dir[File.join(@out, "registry", "*.json")].map { |f| File.basename(f, ".json") }.sort
    end

    def build(name)
      cache = File.join(@out, "registry", "#{name}.json")
      raw = if File.exist?(cache) && (@opts[:offline] || !@opts[:refresh])
        JSON.parse(File.read(cache))
      elsif @opts[:offline]
        warn "oracle: #{name} not cached (offline), skipped"
        return nil
      else
        body = http_get("#{BASE}/styles/#{@opts[:style]}/#{name}.json")
        return warn("oracle: #{name} not in style #{@opts[:style]}, skipped") if body.nil?

        File.write(cache, body)
        JSON.parse(body)
      end
      component = Component.new(name, raw)
      File.write(File.join(@out, "src", "#{name}.tsx"), component.source)
      manifest = component.manifest
      File.write(File.join(@out, "manifest", "#{name}.json"), JSON.pretty_generate(manifest))
      manifest
    end

    def write_graph(manifests)
      nodes = manifests.to_h { |m| [m[:name], m[:registry_dependencies] & manifests.map { |x| x[:name] }] }
      layer = {}
      resolve = lambda do |n, trail|
        raise "dependency cycle: #{(trail + [n]).join(' -> ')}" if trail.include?(n)

        layer[n] ||= nodes[n].empty? ? 1 : 1 + nodes[n].map { |d| resolve.call(d, trail + [n]) }.max
      end
      nodes.each_key { |n| resolve.call(n, []) }
      tiers = manifests.to_h { |m| [m[:name], m[:tier]] }
      waves = layer.group_by { |_, l| l }.sort.map do |l, pairs|
        { wave: l, components: pairs.map(&:first).sort }
      end
      File.write(File.join(@out, "graph.json"), JSON.pretty_generate(nodes: nodes, tiers: tiers, waves: waves))
    end

    def http_get(url, limit = 5)
      uri = URI(url)
      res = Net::HTTP.get_response(uri)
      case res
      when Net::HTTPSuccess then res.body
      when Net::HTTPRedirection then limit.positive? ? http_get(res["location"], limit - 1) : nil
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  opts = { style: "new-york-v4", out: ShadcnLayout::ORACLE_DIR }
  OptionParser.new do |o|
    o.on("--style S") { |v| opts[:style] = v }
    o.on("--out DIR") { |v| opts[:out] = v }
    o.on("--only LIST") { |v| opts[:only] = v.split(",").map(&:strip) }
    o.on("--offline") { opts[:offline] = true }
    o.on("--refresh") { opts[:refresh] = true }
    o.on("--list") { opts[:list] = true }
    o.on("--verify-catalog DIR") { |v| opts[:verify_catalog] = v }
  end.parse!
  ShadcnOracle::Runner.new(opts).run
end

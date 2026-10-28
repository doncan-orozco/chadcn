#!/usr/bin/env ruby
# frozen_string_literal: true

# Gate G1 (static parity) for the shadcn -> Phlex port. Deterministic, no browser.
# Compares a Phlex component file against the oracle manifest.
#
#   ruby .claude/scripts/shadcn/static_gate.rb --component button
#   ruby .claude/scripts/shadcn/static_gate.rb --component button --files path/a.rb,path/b.rb \
#        --oracle <oracle dir> --deviations <deviations dir>
#
# Exit status 0 = pass, 1 = findings with severity MANDATORY, 2 = usage error.
# Always prints one JSON object on stdout: { component:, pass:, findings: [...] }.
#
# Finding codes (cite them in reports):
#   G1_FILE_MISSING     no Phlex file for the component
#   G1_PART_MISSING     React exported part has no Phlex class
#   G1_SLOT_MISSING     data-slot of a part never emitted (parts Radix renders no element for, e.g. Dialog Root/Portal, are exempt: `non_rendered_slots`)
#   G1_DATA_ATTR_MISSING  static data-* attribute (e.g. data-variant, data-size) never emitted
#   G1_TOKEN_MISSING    Tailwind token in the React source absent from the port (style drift)
#   G1_TOKEN_EXTRA      Tailwind token in the port that React does not have (style drift)
#   G1_VARIANT_MISSING  cva variant option not handled
#   G1_DEFAULT_WRONG    cva defaultVariants not reproduced as kwarg defaults
#   G1_KWARG_MISSING    React prop with no matching snake_case kwarg
#   G1_HARDCODED_COLOR  hex/rgb/hsl/oklch literal or palette class outside the oracle

require_relative "layout"
require "json"
require "optparse"
require_relative "oracle_extract"

module ShadcnStaticGate
  PALETTE = /\b(?:bg|text|border|ring|fill|stroke|outline|from|to|via|divide|shadow)-(?:slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-\d{2,3}\b/
  COLOR_LITERAL = /#(?:[0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b|\b(?:rgb|rgba|hsl|hsla|oklch)\(/
  UTILITY = %r{\A[!\-\w\[\]():/.&>*%=,'#@+]+\z}
  IGNORED_PROPS = %w[className children props ...props].freeze

  Finding = Struct.new(:code, :severity, :part, :detail, :expected, :found, keyword_init: true)

  class Checker
    def initialize(manifest, files, deviations)
      @m = manifest
      @src = files.map { |f| File.read(f) }.join("\n").gsub(/\\\n/, "") # Ruby line continuation inside strings
      @dev = deviations
      @literals = literals_of(@src)
      @port_tokens = ShadcnOracle::Scan.tokens(@literals).uniq
    end

    def call
      findings = []
      findings.concat(check_parts)
      findings.concat(check_slots)
      findings.concat(check_data_attrs)
      findings.concat(check_tokens)
      findings.concat(check_variants)
      findings.concat(check_kwargs)
      findings.concat(check_colors)
      findings
    end

    private

    # The scanner is a regexp over the source text, so it must see what the Ruby parser sees: full-line comments never emit markup (and an
    # apostrophe in prose would pair with a later quote and swallow code), and `%w[a b]` words are string literals just like ["a", "b"].
    def literals_of(source)
      code = source.lines.reject { |line| line.lstrip.start_with?("#") }.join
      ShadcnOracle::Scan.string_literals(code) + code.scan(/%w\[([^\]]*)\]/).flat_map { |(words)| words.split }
    end

    def root
      @root ||= ShadcnLayout.root_class_name(@m["name"])
    end

    def short(part_name)
      part_name.start_with?(root) && part_name != root ? part_name.delete_prefix(root) : part_name
    end

    def check_parts
      @m["parts"].filter_map do |part|
        next if part["name"].match?(/\A(use|[a-z])/) # hooks / helpers
        names = [part["name"], short(part["name"])].uniq
        next if names.any? { |n| @src.match?(/\b(?:class|module)\s+(?:\w+::)*#{n}\b/) }

        Finding.new(code: "G1_PART_MISSING", severity: "MANDATORY", part: part["name"],
                    detail: "No Phlex class for React part #{part['name']} (expected `#{root}::#{short(part['name'])}` or `#{part['name']}`)",
                    expected: part["name"])
      end
    end

    def check_slots
      (@m["data_slots"] - Array(@m["non_rendered_slots"])).filter_map do |slot|
        next if @src.match?(/data[-_]slot["']?\s*(?:=>|:)\s*["']#{Regexp.escape(slot)}["']/) ||
                @src.match?(/\bslot:\s*["']#{Regexp.escape(slot)}["']/) ||
                @src.match?(/["']data-slot["']\s*=>\s*["']#{Regexp.escape(slot)}["']/)

        Finding.new(code: "G1_SLOT_MISSING", severity: "MANDATORY", detail: "data-slot=\"#{slot}\" is never emitted", expected: slot)
      end
    end

    def check_data_attrs
      Array(@m["data_attrs"]).filter_map do |attr|
        underscored = attr.tr("-", "_")
        next if @src.include?("\"#{attr}\"") || @src.match?(/\b#{Regexp.escape(underscored)}:/) || @src.match?(/\bdata:\s*\{[^}]*\b#{Regexp.escape(underscored.delete_prefix('data_'))}:/m)

        Finding.new(code: "G1_DATA_ATTR_MISSING", severity: "MANDATORY", detail: "#{attr} is never emitted", expected: attr)
      end
    end

    def check_tokens
      oracle = @m["class_tokens"]
      allow_missing = Array(@dev["allow_missing_tokens"])
      allow_extra = Array(@dev["allow_tokens"])
      missing = (oracle - @port_tokens - allow_missing).sort
      out = missing.map do |t|
        Finding.new(code: "G1_TOKEN_MISSING", severity: "MANDATORY", detail: "Tailwind token from shadcn source missing: #{t}", expected: t)
      end
      extra = @literals.flat_map do |lit|
        toks = lit.split(/\s+/).reject(&:empty?)
        next [] if lit.include?("->") || lit.include?("#{ShadcnLayout::STIMULUS_PREFIX}--") || toks.size < 2
        next [] unless toks.all? { |t| UTILITY.match?(t) }
        next [] unless toks.size >= 4 || (toks & oracle).any?

        toks - oracle - allow_extra
      end.uniq.sort
      out + extra.map do |t|
        Finding.new(code: "G1_TOKEN_EXTRA", severity: "MANDATORY", detail: "Tailwind token not in shadcn source: #{t}", found: t)
      end
    end

    def option_present?(opt)
      variants = [opt, opt.tr("-", "_")].uniq.map { |o| Regexp.escape(o) }
      variants.any? do |o|
        @src.match?(/["']#{o}["']/) || @src.match?(/(?<![\w-]):"?#{o}"?(?![\w-])/) || @src.match?(/(?<![\w."'-])#{o}:\s/)
      end
    end

    def check_variants
      @m["cva"].flat_map do |cva_name, cva|
        found = cva["variants"].flat_map do |axis, options|
          options.keys.reject { |o| o == "false" || o == "true" }.filter_map do |opt|
            next if option_present?(opt)

            Finding.new(code: "G1_VARIANT_MISSING", severity: "MANDATORY", detail: "#{cva_name}.#{axis}=#{opt} not handled", expected: "#{axis}:#{opt}")
          end
        end
        defaults = cva["defaults"].filter_map do |axis, value|
          kw = axis.gsub(/([A-Z])/) { "_#{$1.downcase}" }
          next if @src.match?(/\b#{kw}:\s*(?::|["'])#{Regexp.escape(value.to_s)}/) || @src.match?(/\b#{kw}\s*=\s*(?::|["'])#{Regexp.escape(value.to_s)}/)

          Finding.new(code: "G1_DEFAULT_WRONG", severity: "MANDATORY", detail: "default #{axis}=#{value} not reproduced as kwarg default", expected: "#{kw}: #{value.inspect}")
        end
        found + defaults
      end
    end

    def check_kwargs
      return [] if @m["parts"].none? { |p| p["props"]["typed"].any? || p["props"]["destructured"].any? { |d| !d["rest"] && d["name"] != "className" } }

      signatures = @src.scan(/def initialize\((.*?)\)\s*$/m).flatten.join(" ")
      @m["parts"].flat_map do |part|
        names = part["props"]["destructured"].reject { |p| p["rest"] }.map { |p| p["name"] } + part["props"]["typed"].map { |p| p["name"] }
        # A renamed destructure (`open: openProp`) is listed as "open: openProp"; the kwarg is the public name before the colon.
        names = names.map { |n| n.split(":").first.strip }
        (names.uniq - IGNORED_PROPS).filter_map do |prop|
          next if prop.match?(/\Aon[A-Z]/) # events become Stimulus dispatches, covered by the behavior gate

          kw = prop.gsub(/([A-Z])/) { "_#{$1.downcase}" }
          next if signatures.match?(/\b#{kw}:/)

          Finding.new(code: "G1_KWARG_MISSING", severity: "MANDATORY", part: part["name"], detail: "React prop `#{prop}` has no `#{kw}:` kwarg in any initialize", expected: kw)
        end
      end
    end

    def check_colors
      allowed = @m["class_tokens"] + Array(@dev["allow_tokens"])
      # A colour inside a class token that exists verbatim in the oracle (e.g. `bg-[oklch(from_var(--primary)_l_c_h/0.1)]`) is the source of truth (R2).
      oracle_tokens = @m["class_tokens"]
      hits = @literals.flat_map do |l|
        l.split(/\s+/).reject { |t| oracle_tokens.include?(t) }.flat_map { |t| t.scan(COLOR_LITERAL) + t.scan(PALETTE) }
      end.uniq - allowed
      hits.map { |h| Finding.new(code: "G1_HARDCODED_COLOR", severity: "MANDATORY", detail: "Hardcoded color outside the semantic tokens: #{h}", found: h) }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  opts = { oracle: ShadcnLayout::ORACLE_DIR, deviations: ShadcnLayout::DEVIATIONS_DIR }
  OptionParser.new do |o|
    o.on("--component NAME") { |v| opts[:component] = v }
    o.on("--files LIST") { |v| opts[:files] = v.split(",") }
    o.on("--oracle DIR") { |v| opts[:oracle] = v }
    o.on("--deviations DIR") { |v| opts[:deviations] = v }
  end.parse!
  abort("usage: --component NAME [--files a.rb,b.rb]") unless opts[:component]

  name = opts[:component]
  manifest = JSON.parse(File.read(File.join(opts[:oracle], "manifest", "#{name}.json")))
  files = opts[:files] || ShadcnLayout.component_files(name)
  files = files.select { |f| File.file?(f) }
  dev_file = File.join(opts[:deviations], "#{name}.json")
  deviations = File.exist?(dev_file) ? JSON.parse(File.read(dev_file)) : {}

  findings = if files.empty?
    [ShadcnStaticGate::Finding.new(code: "G1_FILE_MISSING", severity: "MANDATORY", detail: "No Phlex file for #{name}")]
  else
    ShadcnStaticGate::Checker.new(manifest, files, deviations).call
  end
  puts JSON.pretty_generate(component: name, files: files, pass: findings.none? { |f| f.severity == "MANDATORY" }, findings: findings.map(&:to_h))
  exit(findings.any? { |f| f.severity == "MANDATORY" } ? 1 : 0)
end

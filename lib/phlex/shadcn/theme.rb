# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "fileutils"

module Phlex
  module Shadcn
    # Developer-facing theme tooling for the shadcn port.
    #
    # The only file a developer edits is theme.css in the configured theme directory. Its color section sits
    # between `theme:colors:start/end` markers and holds a plain shadcn theme (`:root {}` + `.dark {}`),
    # so anything copied from ui.shadcn.com/themes pastes in unchanged.
    module Theme
      # Raised for an unusable theme: unknown preset, missing markers, a palette with errors, no `:root`/`.dark` block, or no theme
      # directory configured.
      class Error < StandardError; end

      # Marker that opens the colors section of theme.css (rewritten by {.use} and {.import}).
      #
      # @return [String]
      COLORS_START = "/* theme:colors:start */"
      # Marker that closes the colors section of theme.css.
      #
      # @return [String]
      COLORS_END = "/* theme:colors:end */"

      # Variables every theme has to define in both `:root` and `.dark` (the shadcn v4 contract).
      #
      # @return [Array<String>]
      REQUIRED = %w[
        background foreground card card-foreground popover popover-foreground primary primary-foreground
        secondary secondary-foreground muted muted-foreground accent accent-foreground destructive border input ring
        chart-1 chart-2 chart-3 chart-4 chart-5
        sidebar sidebar-foreground sidebar-primary sidebar-primary-foreground sidebar-accent sidebar-accent-foreground
        sidebar-border sidebar-ring
      ].freeze
      # Variables required in `:root` only.
      #
      # @return [Array<String>]
      ROOT_ONLY = %w[radius].freeze

      # Foreground/background pairs that carry text. Alpha colors are skipped (cannot be judged alone).
      CONTRAST_PAIRS = [
        %w[foreground background], %w[card-foreground card], %w[popover-foreground popover],
        %w[primary-foreground primary], %w[secondary-foreground secondary], %w[muted-foreground muted],
        %w[accent-foreground accent], %w[sidebar-foreground sidebar], %w[sidebar-primary-foreground sidebar-primary],
        %w[sidebar-accent-foreground sidebar-accent]
      ].freeze
      # Minimum text contrast ratio (WCAG AA) a foreground/background pair has to reach; below it {.check} warns, or fails when strict.
      #
      # @return [Float]
      MIN_CONTRAST = 4.5

      # Parsed palette: variables for :root and for .dark.
      Palette = Struct.new(:root, :dark, keyword_init: true)

      module_function

      # The directory that holds theme.css and presets/: `Phlex::Shadcn.config.theme_dir`. The engine sets it from
      # `config.phlex_shadcn.theme_dir` (default: the app's app/assets/tailwind/theme); outside an app it has to be configured.
      def dir
        Phlex::Shadcn.config.theme_dir || raise(Error, "Phlex::Shadcn.config.theme_dir is not set (host apps: config.phlex_shadcn.theme_dir)")
      end

      # Whether a directory has been configured (`dir` raises while it is not).
      def configured? = !Phlex::Shadcn.config.theme_dir.nil?

      # Path of the theme file the tasks edit.
      #
      # @return [String] `<dir>/theme.css`
      # @raise [Phlex::Shadcn::Theme::Error] when no theme directory is configured
      def theme_file = File.join(dir, "theme.css")

      # Directory of the preset palettes.
      #
      # @return [String] `<dir>/presets`
      # @raise [Phlex::Shadcn::Theme::Error] when no theme directory is configured
      def presets_dir = File.join(dir, "presets")

      # Names of the available presets (`neutral`, `slate`...), from the `.css` files in {.presets_dir}.
      #
      # @return [Array<String>] sorted names, without the extension
      # @raise [Phlex::Shadcn::Theme::Error] when no theme directory is configured
      def presets
        Dir[File.join(presets_dir, "*.css")].map { |f| File.basename(f, ".css") }.sort
      end

      # ---- parsing -------------------------------------------------------------------------------

      def parse(css)
        Palette.new(root: variables(block(css, ":root")), dark: variables(block(css, ".dark")))
      end

      def block(css, selector)
        start = css.index(/^\s*#{Regexp.escape(selector)}\s*\{/)
        return "" unless start

        open_idx = css.index("{", start)
        depth = 0
        i = open_idx
        while i < css.size
          depth += 1 if css[i] == "{"
          depth -= 1 if css[i] == "}"
          return css[(open_idx + 1)...i] if depth.zero?

          i += 1
        end
        css[(open_idx + 1)..]
      end

      def variables(body)
        body.scan(/--([\w-]+)\s*:\s*([^;]+);/).to_h { |k, v| [ k, v.strip ] }
      end

      # Older shadcn themes (pre Tailwind 4) use bare HSL triplets: "240 10% 3.9%". Wrap them.
      def normalize_value(value)
        return "hsl(#{value})" if value.match?(/\A-?[\d.]+(deg)?\s+[\d.]+%\s+[\d.]+%\z/)

        value
      end

      # ---- validation ----------------------------------------------------------------------------

      # Returns { errors: [], warnings: [] }.
      def validate(palette, strict: false)
        errors = []
        warnings = []
        { "light (:root)" => palette.root, "dark (.dark)" => palette.dark }.each do |label, vars|
          missing = REQUIRED - vars.keys
          errors << "#{label}: missing #{missing.join(', ')}" if missing.any?
          vars.each do |name, value|
            if value.match?(/\A-?[\d.]+\s+[\d.]+%\s+[\d.]+%\z/)
              errors << "#{label}: --#{name} is a bare HSL triplet (\"#{value}\"); run theme:import to wrap it"
            end
            errors << "#{label}: --#{name} has no value" if value.empty?
          end
          unknown = vars.keys - REQUIRED - ROOT_ONLY
          warnings << "#{label}: unknown variables #{unknown.join(', ')} (kept, not used by components)" if unknown.any?
        end
        errors << "light (:root): missing --radius" unless palette.root.key?("radius")

        { "light" => palette.root, "dark" => palette.dark }.each do |mode, vars|
          CONTRAST_PAIRS.each do |fg, bg|
            ratio = contrast(vars[fg], vars[bg])
            next if ratio.nil? || ratio >= MIN_CONTRAST

            (strict ? errors : warnings) << format("%<mode>s: --%<fg>s on --%<bg>s contrast %<ratio>.2f:1 (< %<min>.1f)", mode: mode, fg: fg, bg: bg, ratio: ratio, min: MIN_CONTRAST)
          end
        end
        { errors: errors, warnings: warnings }
      end

      # ---- color math ----------------------------------------------------------------------------
      # The parameters are the standard color-science symbols (l, c, h, s, v, fg, bg).
      # rubocop:disable Naming/MethodParameterName

      def contrast(fg, bg)
        l1 = luminance(fg)
        l2 = luminance(bg)
        return nil unless l1 && l2

        hi = [ l1, l2 ].max
        lo = [ l1, l2 ].min
        (hi + 0.05) / (lo + 0.05)
      end

      # Relative luminance of a CSS color (oklch / hsl / hex). nil for alpha or unsupported syntax.
      def luminance(color)
        rgb = to_linear_rgb(color.to_s.strip)
        return nil unless rgb

        (0.2126 * rgb[0]) + (0.7152 * rgb[1]) + (0.0722 * rgb[2])
      end

      def to_linear_rgb(color)
        case color
        when /\Aoklch\(\s*([\d.]+)(%?)\s+([\d.]+)\s+([\d.]+)(?:deg)?\s*\)\z/
          l = Regexp.last_match(1).to_f
          l /= 100.0 if Regexp.last_match(2) == "%"
          oklch_to_linear(l, Regexp.last_match(3).to_f, Regexp.last_match(4).to_f)
        when /\Ahsl\(\s*([\d.]+)(?:deg)?\s+([\d.]+)%\s+([\d.]+)%\s*\)\z/
          hsl_to_linear(Regexp.last_match(1).to_f, Regexp.last_match(2).to_f / 100, Regexp.last_match(3).to_f / 100)
        when /\A#(\h{2})(\h{2})(\h{2})\z/
          Regexp.last_match.captures.map { |h| srgb_to_linear(h.to_i(16) / 255.0) }
        end
      end

      def oklch_to_linear(l, c, h)
        a = c * Math.cos(h * Math::PI / 180)
        b = c * Math.sin(h * Math::PI / 180)
        l_ = (l + (0.3963377774 * a) + (0.2158037573 * b))**3
        m_ = (l - (0.1055613458 * a) - (0.0638541728 * b))**3
        s_ = (l - (0.0894841775 * a) - (1.2914855480 * b))**3
        [
          (4.0767416621 * l_) - (3.3077115913 * m_) + (0.2309699292 * s_),
          (-1.2684380046 * l_) + (2.6097574011 * m_) - (0.3413193965 * s_),
          (-0.0041960863 * l_) - (0.7034186147 * m_) + (1.7076147010 * s_)
        ].map { |v| v.clamp(0.0, 1.0) }
      end

      def hsl_to_linear(h, s, l)
        c = (1 - ((2 * l) - 1).abs) * s
        x = c * (1 - (((h / 60) % 2) - 1).abs)
        m = l - (c / 2)
        r, g, b = hue_sector((h % 360) / 60, c, x)
        [ r + m, g + m, b + m ].map { |v| srgb_to_linear(v) }
      end

      # The (r, g, b) triple of an HSL hue sector (0...6) before the lightness offset.
      def hue_sector(sector, c, x)
        case sector
        when 0...1 then [ c, x, 0 ]
        when 1...2 then [ x, c, 0 ]
        when 2...3 then [ 0, c, x ]
        when 3...4 then [ 0, x, c ]
        when 4...5 then [ x, 0, c ]
        else [ c, 0, x ]
        end
      end

      def srgb_to_linear(v)
        v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4
      end
      # rubocop:enable Naming/MethodParameterName

      # ---- rendering and file operations ---------------------------------------------------------

      def render_colors(palette)
        root = palette.root.dup
        radius = root.delete("radius")
        ordered_root = REQUIRED.filter_map { |k| [ k, root[k] ] if root.key?(k) } + (root.keys - REQUIRED).map { |k| [ k, root[k] ] }
        ordered_root << [ "radius", radius ] if radius
        dark = REQUIRED.filter_map { |k| [ k, palette.dark[k] ] if palette.dark.key?(k) } + (palette.dark.keys - REQUIRED).map { |k| [ k, palette.dark[k] ] }
        [
          ":root {", ordered_root.map { |k, v| "  --#{k}: #{v};" }, "}", "",
          ".dark {", dark.map { |k, v| "  --#{k}: #{v};" }, "}", ""
        ].flatten.join("\n")
      end

      # Replaces the colors section of theme.css and returns the validation result. Atomic: nothing is
      # written when the palette has errors.
      def write_colors(palette, source_label:)
        result = validate(palette)
        raise Error, "refusing to write an invalid theme:\n  #{result[:errors].join("\n  ")}" if result[:errors].any?

        css = File.read(theme_file)
        raise Error, "#{theme_file} lacks the #{COLORS_START} / #{COLORS_END} markers" unless css.include?(COLORS_START) && css.include?(COLORS_END)

        section = "#{COLORS_START}\n/* source: #{source_label} */\n#{render_colors(palette)}#{COLORS_END}"
        File.write(theme_file, css.sub(/#{Regexp.escape(COLORS_START)}.*?#{Regexp.escape(COLORS_END)}/mo, section.gsub("\\", "\\\\\\\\")))
        result
      end

      def use(name)
        file = File.join(presets_dir, "#{name}.css")
        raise Error, "unknown preset '#{name}'. Available: #{presets.join(', ')}" unless File.exist?(file)

        write_colors(parse(File.read(file)), source_label: "preset #{name}")
      end

      # source: path to a CSS file, an http(s) URL, or "-" for stdin. Fills variables a pasted theme
      # lacks from the current theme (and reports which), wraps legacy bare HSL triplets.
      def import(source, input: $stdin)
        css = read_source(source, input)
        pasted = parse(css)
        raise Error, "no :root { } or .dark { } block found in #{source}" if pasted.root.empty? && pasted.dark.empty?

        current = parse(File.read(theme_file))
        filled = []
        merged = Palette.new(
          root: fill(pasted.root, current.root, "light", filled),
          dark: fill(pasted.dark, current.dark, "dark", filled)
        )
        result = write_colors(merged, source_label: "imported #{source}")
        result.merge(filled: filled)
      end

      def fill(pasted, current, label, filled)
        values = pasted.transform_values { |v| normalize_value(v) }
        (REQUIRED + (label == "light" ? ROOT_ONLY : [])).each do |name|
          next if values.key?(name)
          next unless current.key?(name)

          values[name] = current[name]
          filled << "#{label}: --#{name} (kept current value)"
        end
        values
      end

      def read_source(source, input)
        if source == "-"
          input.read
        elsif source.match?(%r{\Ahttps?://})
          Net::HTTP.get(URI(source))
        else
          File.read(source)
        end
      end

      # Validates the current theme.css: variables complete in light and dark, valid values, text contrast.
      #
      # @param strict [Boolean] when true a contrast below {MIN_CONTRAST} is an error instead of a warning
      # @return [Hash{Symbol => Array<String>}] `{ errors: [...], warnings: [...] }`
      # @raise [Phlex::Shadcn::Theme::Error] when no theme directory is configured
      # @raise [Errno::ENOENT] when theme.css does not exist
      def check(strict: false)
        validate(parse(File.read(theme_file)), strict: strict)
      end

      # Parsing, color math and file helpers behind the methods above.
      private_class_method :block, :variables, :normalize_value, :luminance, :to_linear_rgb, :oklch_to_linear, :hsl_to_linear,
                           :srgb_to_linear, :hue_sector, :render_colors, :write_colors, :fill, :read_source
    end
  end
end

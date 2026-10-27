# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "fileutils"
require "openssl"
require "timeout"

module Chadcn
  # Developer-facing theme tooling for the shadcn port.
  #
  # The only file a developer edits is theme.css in the configured theme directory. Its color section sits
  # between `theme:colors:start/end` markers and holds a plain shadcn theme (`:root {}` + `.dark {}`),
  # so anything copied from ui.shadcn.com/themes pastes in unchanged.
  #
  # The public surface is {.use}, {.import}, {.check}, {.presets}, {.dir}, {.configured?}, {.theme_file} and {.presets_dir}
  # (the `chadcn:theme:*` rake tasks call them), plus the palette helpers a host app can use without touching the theme file:
  # {.parse}, {.validate}, {.contrast} and {.render_colors}. The helpers behind {.use} and {.import} (writing the file, fetching a URL) stay `@api private`.
  #
  # @example Switch to a preset, then check the result
  #   Chadcn::Theme.use("slate")
  #   Chadcn::Theme.check # => { errors: [], warnings: [] }
  module Theme
    # Raised for an unusable theme: unknown preset, missing markers, a palette with errors, no `:root`/`.dark` block, no theme
    # directory configured, or an import source that cannot be read or fetched. A missing theme.css is the plain `Errno::ENOENT`.
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
    #
    # @api private
    # @return [Array<Array<String>>]
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

    # Longest redirect chain {.import} follows.
    #
    # @api private
    # @return [Integer]
    IMPORT_MAX_REDIRECTS = 3
    # Largest source, in bytes, {.import} accepts (from a URL, a file or stdin).
    #
    # @api private
    # @return [Integer]
    IMPORT_MAX_BYTES = 256 * 1024
    # Seconds {.import} waits to open a connection to a URL.
    #
    # @api private
    # @return [Integer]
    IMPORT_OPEN_TIMEOUT = 5
    # Seconds {.import} waits for each read from a URL.
    #
    # @api private
    # @return [Integer]
    IMPORT_READ_TIMEOUT = 10
    # Text that can break out of a CSS declaration or comment: a comment delimiter, braces, a semicolon, a backslash (CSS escapes
    # such as `u\72l(` spell `url(`) or `url(`.
    #
    # @api private
    # @return [Regexp]
    UNSAFE_VALUE = %r{/\*|\*/|[{};\\]|url\(}i

    # Parsed palette: variables for :root and for .dark.
    #
    # @!attribute [rw] root
    #   @return [Hash{String => String}] the `:root` variables, without the leading dashes
    # @!attribute [rw] dark
    #   @return [Hash{String => String}] the `.dark` variables, without the leading dashes
    Palette = Struct.new(:root, :dark, keyword_init: true)

    module_function

    # The directory that holds theme.css and presets/: `Chadcn.config.theme_dir`. The engine sets it from
    # `config.chadcn.theme_dir` (default: the app's app/assets/tailwind/theme); outside an app it has to be configured.
    #
    # @return [String]
    # @raise [Chadcn::Theme::Error] when no theme directory is configured
    def dir
      Chadcn.config.theme_dir || raise(Error, "Chadcn.config.theme_dir is not set (host apps: config.chadcn.theme_dir)")
    end

    # Whether a directory has been configured ({.dir} raises while it is not).
    #
    # @return [Boolean]
    def configured? = !Chadcn.config.theme_dir.nil?

    # Path of the theme file the tasks edit.
    #
    # @return [String] `<dir>/theme.css`
    # @raise [Chadcn::Theme::Error] when no theme directory is configured
    def theme_file = File.join(dir, "theme.css")

    # Directory of the preset palettes.
    #
    # @return [String] `<dir>/presets`
    # @raise [Chadcn::Theme::Error] when no theme directory is configured
    def presets_dir = File.join(dir, "presets")

    # Names of the available presets (`neutral`, `slate`...), from the `.css` files in {.presets_dir}.
    #
    # @return [Array<String>] sorted names, without the extension
    # @raise [Chadcn::Theme::Error] when no theme directory is configured
    def presets
      Dir[File.join(presets_dir, "*.css")].map { |f| File.basename(f, ".css") }.sort
    end

    # ---- parsing -------------------------------------------------------------------------------

    # Reads the `:root` and `.dark` variables of a shadcn theme.
    #
    # @param css [String] CSS text holding a `:root { }` block and optionally a `.dark { }` block
    # @return [Palette]
    # @raise [Chadcn::Theme::Error] when a block has unbalanced braces (a missing block just yields no variables)
    # @example
    #   palette = Chadcn::Theme.parse(":root { --background: #fff; } .dark { --background: #000; }")
    #   palette.root["background"] # => "#fff"
    def parse(css)
      Palette.new(root: variables(block(css, ":root")), dark: variables(block(css, ".dark")))
    end

    # @api private
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
      raise Error, "unterminated #{selector} block (unbalanced braces)"
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

    # Checks a palette: complete variables, plain values, text contrast. Nothing is written.
    #
    # @param palette [Palette]
    # @param strict [Boolean] when true a contrast below {MIN_CONTRAST} is an error instead of a warning
    # @return [Hash{Symbol => Array<String>}] `{ errors: [...], warnings: [...] }`
    # @example A palette missing every other variable reports them
    #   palette = Chadcn::Theme.parse(":root { --background: #fff; }")
    #   Chadcn::Theme.validate(palette)[:errors].first # => "light (:root): missing foreground, card, ..."
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
          errors << "#{label}: --#{name} contains text that could break theme.css (#{value[UNSAFE_VALUE]})" if value.match?(UNSAFE_VALUE)
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

    # WCAG contrast ratio between two CSS colors: `oklch()`, space-separated `hsl()` or 6-digit `#rrggbb` hex.
    #
    # @param fg [String] foreground color
    # @param bg [String] background color
    # @return [Float, nil] the ratio (1.0 to 21.0), nil when either color has alpha or another syntax (named colors, `rgb()`, `#rgb`, 8-digit hex);
    #   {.validate} then skips that pair
    # @example
    #   Chadcn::Theme.contrast("#000000", "#ffffff") # => 21.0
    def contrast(fg, bg)
      l1 = luminance(fg)
      l2 = luminance(bg)
      return nil unless l1 && l2

      hi = [ l1, l2 ].max
      lo = [ l1, l2 ].min
      (hi + 0.05) / (lo + 0.05)
    end

    # Relative luminance of a CSS color (oklch / hsl / hex). nil for alpha or unsupported syntax.
    #
    # @api private
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

    # Renders a palette as the `:root { }` / `.dark { }` text that theme.css and the preset files hold: the required variables first
    # (in {REQUIRED} order), any extras after them, and `--radius` last in `:root`. Usable as an export.
    #
    # @param palette [Palette] the parsed variables for `:root` and `.dark`
    # @return [String] the CSS text, ending with a newline
    # @example For a palette returned by {.parse}, rendering and parsing again gives the same palette
    #   Chadcn::Theme.parse(Chadcn::Theme.render_colors(palette)) == palette # => true
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

    # Replaces the colors section of theme.css and returns the validation result. Nothing is written when the palette has
    # errors, and the file is replaced in one step (written next to it, then renamed), so a failure half-way leaves it as it was.
    #
    # @api private
    def write_colors(palette, source_label:)
      result = validate(palette)
      raise Error, "refusing to write an invalid theme:\n  #{result[:errors].join("\n  ")}" if result[:errors].any?

      css = File.read(theme_file)
      raise Error, "#{theme_file} lacks the #{COLORS_START} / #{COLORS_END} markers" unless css.include?(COLORS_START) && css.include?(COLORS_END)

      section = "#{COLORS_START}\n/* source: #{comment_text(source_label)} */\n#{render_colors(palette)}#{COLORS_END}"
      replace_theme_file(css.sub(/#{Regexp.escape(COLORS_START)}.*?#{Regexp.escape(COLORS_END)}/mo) { section })
      result
    end

    # Writes the new theme.css next to the old one (same permissions, a name unique to this process) and renames it over, so
    # readers never see a half-written file.
    #
    # @api private
    def replace_theme_file(css)
      temp = "#{theme_file}.#{Process.pid}.tmp"
      File.write(temp, css)
      File.chmod(File.stat(theme_file).mode & 0o7777, temp)
      File.rename(temp, theme_file)
    ensure
      File.delete(temp) if temp && File.exist?(temp)
    end

    # Text that is safe inside a CSS comment: one line, no comment delimiters, bounded length.
    #
    # @api private
    def comment_text(text)
      text.to_s.gsub(/\s+/, " ").gsub("*/", "* /").gsub("/*", "/ *").strip[0, 200]
    end

    # Rewrites the colors of theme.css from a preset.
    #
    # @param name [String] preset name, one of {.presets}
    # @return [Hash{Symbol => Array<String>}] the validation result, `{ errors: [], warnings: [...] }`
    # @raise [Chadcn::Theme::Error] for an unknown preset (only a name listed by {.presets}, never a path), a preset with
    #   errors, a theme.css without the color markers, or no configured theme directory
    # @raise [Errno::ENOENT] when theme.css does not exist
    # @example
    #   Chadcn::Theme.use("slate")
    def use(name)
      raise Error, "unknown preset '#{name}'. Available: #{presets.join(', ')}" unless presets.include?(name.to_s)

      write_colors(parse(File.read(File.join(presets_dir, "#{name}.css"))), source_label: "preset #{name}")
    end

    # Rewrites the colors of theme.css from a shadcn theme pasted from ui.shadcn.com/themes. Variables the pasted theme lacks
    # are kept from the current theme (and reported) and legacy bare HSL triplets are wrapped in `hsl()`. Nothing is written when
    # the result is invalid.
    #
    # A URL has to be `https`: it is fetched with a 5 s open and 10 s read timeout, at most 3 redirects (each `https`) and a
    # 256 KiB body (the same cap applies to a file or stdin source). Values that could break theme.css (comment delimiters,
    # braces, semicolons, backslashes, `url(`) are rejected. A URL with credentials (`https://user:pass@host`) is refused, also
    # as a redirect target.
    #
    # Developer tooling, run by the developer on their own machine: the URL is fetched as given, with no host allow-list
    # (loopback and link-local addresses are reachable, also through redirects). Never pass untrusted input, and do not expose
    # it to end users.
    #
    # @param source [String] path to a CSS file, an `https://` URL, or `"-"` for the `input` stream
    # @param input [IO] where `"-"` is read from
    # @return [Hash{Symbol => Array<String>}] `{ errors: [], warnings: [...], filled: [...] }`
    # @raise [Chadcn::Theme::Error] for an unreadable or unreachable source, a non-https URL, a URL with credentials, a non-200 answer, too many
    #   redirects, an oversize or non-UTF-8 source, a theme without `:root`/`.dark` blocks, an invalid palette, a theme.css without
    #   the color markers, or no configured theme directory
    # @raise [Errno::ENOENT] when theme.css does not exist
    # @example
    #   Chadcn::Theme.import("https://example.com/my-theme.css")
    #   Chadcn::Theme.import("my-theme.css")
    def import(source, input: $stdin)
      css = read_source(source, input)
      pasted = parse(css)
      raise Error, "no :root { } or .dark { } block found in #{comment_text(source)}" if pasted.root.empty? && pasted.dark.empty?

      current = parse(File.read(theme_file))
      filled = []
      merged = Palette.new(
        root: fill(pasted.root, current.root, "light", filled),
        dark: fill(pasted.dark, current.dark, "dark", filled)
      )
      result = write_colors(merged, source_label: "imported #{source}")
      result.merge(filled: filled)
    end

    # @api private
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

    # Every source is capped at {IMPORT_MAX_BYTES} (a file or stream is read one byte past the cap to tell) and has to be UTF-8.
    #
    # @api private
    def read_source(source, input)
      css = if source == "-"
        input.read(IMPORT_MAX_BYTES + 1) || ""
      elsif source.match?(%r{\A[a-z][a-z0-9+.-]*://}i)
        fetch(source)
      else
        read_file(source)
      end
      raise Error, "#{comment_text(source)} is larger than #{IMPORT_MAX_BYTES / 1024} KiB" if css.bytesize > IMPORT_MAX_BYTES

      css = css.dup.force_encoding(Encoding::UTF_8)
      raise Error, "#{comment_text(source)} is not valid UTF-8 text" unless css.valid_encoding?

      css
    end

    # @api private
    def read_file(path)
      File.binread(path, IMPORT_MAX_BYTES + 1) || ""
    rescue SystemCallError => e
      raise Error, "cannot read #{path}: #{e.message}"
    end

    # GET of an https URL, following at most {IMPORT_MAX_REDIRECTS} https redirects.
    #
    # @api private
    def fetch(url)
      uri = https_uri(url)
      (IMPORT_MAX_REDIRECTS + 1).times do
        status, location, body = http_get(uri)
        return body if status == 200
        raise Error, "#{uri} answered HTTP #{status}" unless [ 301, 302, 303, 307, 308 ].include?(status)
        raise Error, "#{uri} redirected without a Location" if location.to_s.empty?

        uri = https_uri(redirect_target(uri, location))
      end
      raise Error, "#{url} redirected more than #{IMPORT_MAX_REDIRECTS} times"
    end

    # @api private
    def redirect_target(uri, location)
      URI.join(uri.to_s, location).to_s
    rescue URI::Error
      raise Error, "#{uri} redirected to an invalid location"
    end

    # @api private
    def https_uri(url)
      uri = URI.parse(url)
      if uri.userinfo
        raise Error, "URLs with credentials cannot be imported (host #{uri.host}); download the file and import its path"
      end
      raise Error, "only https:// URLs can be imported (got #{url})" unless uri.is_a?(URI::HTTPS)
      raise Error, "#{url} has no host" if uri.host.to_s.empty?

      uri
    rescue URI::Error
      raise Error, "#{comment_text(url)} is not a valid URL"
    end

    # One request. Returns [status, Location header, body]; the body is read only for a 200 and capped at {IMPORT_MAX_BYTES}.
    # The request asks for an identity encoding, so nothing is inflated and no Zlib error can occur. Every failure the client
    # raises (timeouts, DNS and socket errors, TLS, a malformed status line or header) is wrapped in {Error}.
    #
    # @api private
    def http_get(uri)
      options = { use_ssl: true, open_timeout: IMPORT_OPEN_TIMEOUT, read_timeout: IMPORT_READ_TIMEOUT }
      answer = nil
      Net::HTTP.start(uri.hostname, uri.port, **options) do |http|
        request = Net::HTTP::Get.new(uri)
        request["Accept-Encoding"] = "identity"
        http.request(request) do |response|
          status = response.code.to_i
          answer = [ status, response["location"], (capped_body(response, uri) if status == 200) ]
        end
      end
      answer
    rescue Timeout::Error, SocketError, SystemCallError, IOError, OpenSSL::OpenSSLError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
           Net::ProtocolError => e
      raise Error, "cannot fetch #{uri}: #{e.message}"
    end

    # @api private
    def capped_body(response, uri)
      body = +"".b
      response.read_body do |chunk|
        raise Error, "#{uri} is larger than #{IMPORT_MAX_BYTES / 1024} KiB" if body.bytesize + chunk.bytesize > IMPORT_MAX_BYTES

        body << chunk
      end
      body
    end

    # Validates the current theme.css: variables complete in light and dark, valid values, text contrast.
    #
    # @param strict [Boolean] when true a contrast below {MIN_CONTRAST} is an error instead of a warning
    # @return [Hash{Symbol => Array<String>}] `{ errors: [...], warnings: [...] }`
    # @raise [Chadcn::Theme::Error] when no theme directory is configured
    # @raise [Errno::ENOENT] when theme.css does not exist
    def check(strict: false)
      validate(parse(File.read(theme_file)), strict: strict)
    end

    # Parsing, color math and file helpers behind the methods above.
    private_class_method :block, :variables, :normalize_value, :luminance, :to_linear_rgb, :oklch_to_linear, :hsl_to_linear,
                         :srgb_to_linear, :hue_sector, :write_colors, :replace_theme_file, :comment_text, :fill, :read_source, :read_file,
                         :fetch, :redirect_target, :https_uri, :http_get, :capped_body
  end
end

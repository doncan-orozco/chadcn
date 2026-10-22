# frozen_string_literal: true

require "chadcn/test_case"
require "tmpdir"
require "stringio"

class Chadcn::ThemeTest < Chadcn::TestCase
  Theme = Chadcn::Theme
  ASSETS = Chadcn.root.join("app/assets/tailwind/chadcn")

  HSL_THEME = <<~CSS
    :root {
      --background: 0 0% 100%;
      --foreground: 240 10% 3.9%;
      --primary: 240 5.9% 10%;
      --primary-foreground: 0 0% 98%;
      --radius: 0.5rem;
    }
    .dark {
      --background: 240 10% 3.9%;
      --foreground: 0 0% 98%;
    }
  CSS

  def setup
    @original_dir = Chadcn.config.theme_dir
    @theme_dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@theme_dir, "presets"))
    FileUtils.cp(ASSETS.join("theme.css"), File.join(@theme_dir, "theme.css"))
    Dir[ASSETS.join("presets/*.css").to_s].each { |preset| FileUtils.cp(preset, File.join(@theme_dir, "presets")) }
    Chadcn.configure { |config| config.theme_dir = @theme_dir }
  end

  def teardown
    Chadcn.configure { |config| config.theme_dir = @original_dir }
    FileUtils.remove_entry(@theme_dir)
  end

  test "the directory has to be configured and the error says how" do
    Chadcn.configure { |config| config.theme_dir = nil }

    refute_predicate Theme, :configured?
    error = assert_raises(Theme::Error) { Theme.theme_file }

    assert_match(/theme_dir/, error.message)
  end

  test "contrast of white on black is 21:1 and of equal colors is 1:1" do
    assert_in_delta 21.0, Theme.contrast("oklch(1 0 0)", "oklch(0 0 0)"), 0.05
    assert_in_delta 1.0, Theme.contrast("oklch(0.5 0 0)", "oklch(0.5 0 0)"), 0.001
    assert_in_delta 21.0, Theme.contrast("#ffffff", "#000000"), 0.05
  end

  test "colors with alpha are skipped by the contrast check" do
    assert_nil Theme.contrast("oklch(1 0 0 / 10%)", "oklch(0 0 0)")
  end

  test "shipped theme and every preset are valid" do
    assert_empty Theme.check[:errors]
    assert_equal ASSETS.join("presets").children.map { |file| file.basename(".css").to_s }.sort, Theme.presets
    Theme.presets.each do |name|
      palette = Theme.parse(File.read(File.join(@theme_dir, "presets", "#{name}.css")))

      assert_empty Theme.validate(palette)[:errors], name
    end
  end

  test "use switches the colors and keeps the rest of the file" do
    Theme.use("slate")

    css = File.read(Theme.theme_file)

    assert_includes css, "source: preset slate"
    assert_includes css, "theme:brand:start"
    assert_equal Theme.parse(File.read(File.join(@theme_dir, "presets", "slate.css"))).root, Theme.parse(css).root
  end

  test "use and import raise Errno::ENOENT for a missing theme.css, as documented" do
    File.delete(Theme.theme_file)

    assert_raises(Errno::ENOENT) { Theme.use("slate") }
    assert_raises(Errno::ENOENT) { Theme.import("-", input: StringIO.new(HSL_THEME)) }
  end

  test "use takes a preset name, never a path" do
    FileUtils.cp(File.join(@theme_dir, "presets", "slate.css"), File.join(@theme_dir, "outside.css"))
    before = File.read(Theme.theme_file)
    error = assert_raises(Theme::Error) { Theme.use("../outside") }

    assert_match(%r{unknown preset '\.\./outside'}, error.message)
    assert_equal before, File.read(Theme.theme_file)
  end

  test "the write replaces theme.css in one step, keeps its permissions and leaves no temporary file behind" do
    File.chmod(0o640, Theme.theme_file)
    Theme.use("slate")

    assert_includes File.read(Theme.theme_file), "source: preset slate"
    assert_equal 0o640, File.stat(Theme.theme_file).mode & 0o777
    assert_empty Dir[File.join(@theme_dir, "*.tmp")]
  end

  test "a failed rename leaves theme.css as it was and removes the temporary file" do
    before = File.read(Theme.theme_file)
    original = File.method(:rename)
    File.define_singleton_method(:rename) { |*| raise Errno::EACCES, "rename" }

    assert_raises(Errno::EACCES) { Theme.use("slate") }
    assert_equal before, File.read(Theme.theme_file)
    assert_empty Dir[File.join(@theme_dir, "*.tmp")]
  ensure
    File.define_singleton_method(:rename, original)
  end

  test "use rejects an unknown preset listing the available ones" do
    error = assert_raises(Theme::Error) { Theme.use("nope") }

    assert_includes error.message, "slate"
  end

  test "import wraps legacy bare HSL triplets and fills missing variables from the current theme" do
    result = Theme.import("-", input: StringIO.new(HSL_THEME))

    css = File.read(Theme.theme_file)

    assert_includes css, "--primary: hsl(240 5.9% 10%);"
    assert_includes css, "--radius: 0.5rem;"
    assert_includes css, "--sidebar-ring:"
    assert(result[:filled].any? { |f| f.include?("--card (kept current value)") })
    assert_empty Theme.check[:errors]
  end

  test "import refuses input without theme blocks and leaves the file untouched" do
    before = File.read(Theme.theme_file)

    assert_raises(Theme::Error) { Theme.import("-", input: StringIO.new("body { color: red; }")) }
    assert_equal before, File.read(Theme.theme_file)
  end

  test "validate reports missing variables per mode" do
    palette = Theme::Palette.new(root: { "background" => "oklch(1 0 0)" }, dark: {})

    errors = Theme.validate(palette)[:errors]

    assert(errors.any? { |e| e.start_with?("light (:root): missing") && e.include?("primary") })
    assert(errors.any? { |e| e.start_with?("dark (.dark): missing") })
    assert_includes errors, "light (:root): missing --radius"
  end

  test "strict mode turns low contrast into an error" do
    palette = Theme.parse(File.read(File.join(@theme_dir, "presets", "zinc.css")))
    palette.root["muted-foreground"] = "oklch(0.9 0 0)"

    assert_empty Theme.validate(palette)[:errors]
    assert(Theme.validate(palette, strict: true)[:errors].any? { |e| e.include?("muted-foreground") })
  end

  test "render_colors writes required variables first, extras after and --radius last in :root" do
    palette = Theme::Palette.new(
      root: { "radius" => "0.5rem", "brand" => "oklch(0.6 0.2 30)", "ring" => "oklch(0.5 0 0)", "background" => "oklch(1 0 0)" },
      dark: { "brand" => "oklch(0.7 0.2 30)", "background" => "oklch(0.1 0 0)" }
    )

    css = Theme.render_colors(palette)
    root, dark = css.split("\n.dark {")
    root_names = root.scan(/--([\w-]+):/).flatten

    assert_equal %w[background ring brand radius], root_names
    assert_equal %w[background brand], dark.scan(/--([\w-]+):/).flatten
    assert_match(/\A:root \{\n  --background: oklch\(1 0 0\);/, css)
    assert_includes css, ".dark {"
    assert_equal palette.root, Theme.parse(css).root
  end

  test "the module's public surface is the documented set" do
    methods = %i[check configured? contrast dir import parse presets presets_dir render_colors theme_file use validate]
    constants = %i[
      COLORS_END COLORS_START CONTRAST_PAIRS Error IMPORT_MAX_BYTES IMPORT_MAX_REDIRECTS IMPORT_OPEN_TIMEOUT IMPORT_READ_TIMEOUT
      MIN_CONTRAST Palette REQUIRED ROOT_ONLY UNSAFE_VALUE
    ]

    assert_equal methods, Theme.singleton_methods(false).sort
    assert_equal constants, Theme.constants.sort
  end
end

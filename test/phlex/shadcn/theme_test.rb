# frozen_string_literal: true

require "phlex/test_case"
require "tmpdir"
require "stringio"

class Phlex::Shadcn::ThemeTest < Phlex::Shadcn::TestCase
  Theme = Phlex::Shadcn::Theme
  ASSETS = Phlex::Shadcn.root.join("app/assets/tailwind/phlex-shadcn")

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
    @original_dir = Phlex::Shadcn.config.theme_dir
    @theme_dir = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(@theme_dir, "presets"))
    FileUtils.cp(ASSETS.join("theme.css"), File.join(@theme_dir, "theme.css"))
    Dir[ASSETS.join("presets/*.css").to_s].each { |preset| FileUtils.cp(preset, File.join(@theme_dir, "presets")) }
    Phlex::Shadcn.configure { |config| config.theme_dir = @theme_dir }
  end

  def teardown
    Phlex::Shadcn.configure { |config| config.theme_dir = @original_dir }
    FileUtils.remove_entry(@theme_dir)
  end

  test "the directory has to be configured and the error says how" do
    Phlex::Shadcn.configure { |config| config.theme_dir = nil }

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
end

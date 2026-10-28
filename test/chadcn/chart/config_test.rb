# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::ConfigTest < Chadcn::TestCase
  def config(**entries) = Chadcn::Chart::Config.new(**entries)

  test "normalizes symbol and string keys and answers entries by either" do
    from_hash = Chadcn::Chart::Config.new("desktop" => { "label" => "Desktop", "color" => "red" })

    assert_equal %w[desktop], from_hash.keys
    assert_equal "Desktop", from_hash[:desktop].label
    assert_equal "red", from_hash["desktop"].color
    assert from_hash.key?(:desktop)
    assert_nil from_hash[:mobile]
  end

  test "keeps the label, the icon and a theme" do
    entry = config(a: { label: "A", icon: :bell, theme: { light: "#000", dark: "#fff" } })[:a]

    assert_equal "A", entry.label
    assert_equal :bell, entry.icon
    assert_equal({ "light" => "#000", "dark" => "#fff" }, entry.theme)
    assert_nil entry.color
  end

  test "a color together with a theme raises naming the key" do
    error = assert_raises(ArgumentError) { config(desktop: { color: "red", theme: { light: "#000", dark: "#fff" } }) }

    assert_includes error.message, "desktop"
  end

  test "rejects keys and colors that could break out of the style" do
    assert_raises(ArgumentError) { config("a b": { color: "red" }) }
    assert_raises(ArgumentError) { config(a: { color: "red;}" }) }
    assert_raises(ArgumentError) { config(a: { color: "red /* x" }) }
    assert_raises(ArgumentError) { config(a: { color: "red\n/*" }) }
    assert_raises(ArgumentError) { config(a: { theme: { light: "</style>", dark: "#fff" } }) }
    assert_raises(ArgumentError) { config(a: { color: "" }) }
    assert_equal "oklch(0.5 0.2 30)", config(a: { color: "oklch(0.5 0.2 30)" })[:a].color
  end

  test "rejects unknown options and unknown themes" do
    assert_raises(ArgumentError) { config(a: { colour: "red" }) }
    assert_raises(ArgumentError) { config(a: { theme: { sepia: "#000" } }) }
    assert_raises(ArgumentError) { config(a: "red") }
  end

  test "color_entries keeps the entries with a color or a theme" do
    colored = config(a: { label: "A" }, b: { color: "red" }, c: { theme: { light: "#000", dark: "#fff" } })

    assert_equal %w[b c], colored.color_entries.keys
  end

  test "is built from another config and from keywords" do
    first = config(a: { color: "red" })

    assert_equal first.to_h, Chadcn::Chart::Config.new(first).to_h
    assert_equal %w[a b], Chadcn::Chart::Config.new(first, b: { color: "blue" }).keys
  end

  test "payload_config looks the key up in the item, then in its row, then as the key itself" do
    cfg = config(chrome: { label: "Chrome" }, desktop: { label: "Desktop" })

    assert_equal "Desktop", cfg.payload_config({ name: "x" }, "desktop").label
    assert_equal "Chrome", cfg.payload_config({ name: "x", payload: { browser: "chrome" } }, "browser").label
    assert_equal "Chrome", cfg.payload_config({ browser: "chrome", payload: { browser: "desktop" } }, "browser").label
    assert_equal "Desktop", cfg.payload_config({ "payload" => { "browser" => "desktop" } }, "browser").label
  end

  test "payload_config falls back to the key when the named entry does not exist and answers nil for a non-hash payload" do
    cfg = config(browser: { label: "Browser" })

    assert_equal "Browser", cfg.payload_config({ payload: { browser: "unknown" } }, "browser").label
    assert_nil cfg.payload_config(nil, "browser")
    assert_nil cfg.payload_config("browser", "browser")
    assert_nil cfg.payload_config({}, "missing")
  end

  test "a key given as a String and as a Symbol raises" do
    assert_raises(ArgumentError) { Chadcn::Chart::Config.new({ "a" => { color: "red" } }, a: { color: "blue" }) }
  end

  test "a theme with no color is dropped and a one-sided theme keeps its side" do
    assert_nil config(a: { theme: {} })[:a].theme
    assert_nil config(a: { theme: { light: nil } })[:a].theme
    assert_equal({ "light" => "#000" }, config(a: { theme: { light: "#000" } })[:a].theme)
    assert_raises(ArgumentError) { config(a: { theme: "dark" }) }
  end

  test "a color that is not a String raises, and a stored color is frozen" do
    assert_raises(ArgumentError) { config(a: { color: false }) }
    assert_raises(ArgumentError) { config(a: { color: :red }) }
    assert_predicate config(a: { color: +"red" })[:a].color, :frozen?
  end

  test "each, empty? and to_h" do
    cfg = config(a: { label: "A" }, b: { color: "red" })

    assert_equal(%w[a b], cfg.each.map { |key, _entry| key })
    assert_not_predicate cfg, :empty?
    assert_predicate Chadcn::Chart::Config.new, :empty?
    assert_equal({ "a" => { label: "A" }, "b" => { color: "red" } }, cfg.to_h)
  end

  test "keywords win over the positional entries" do
    assert_equal "blue", Chadcn::Chart::Config.new({ a: { color: "red" } }, a: { color: "blue" })[:a].color
  end
end

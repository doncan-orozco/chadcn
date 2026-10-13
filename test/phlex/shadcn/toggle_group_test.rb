# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::ToggleGroupTest < Phlex::Shadcn::TestCase
  ToggleGroup = Phlex::Shadcn::ToggleGroup

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def group(root: { type: "single" }, item: {})
    render_view do
      render(ToggleGroup.new(**root)) do
        render(ToggleGroup::Item.new(value: "a", **item))
        render(ToggleGroup::Item.new(value: "b"))
      end
    end
  end

  test "single root renders radix attributes, slot and merged class" do
    root = fragment(group(root: { type: :single, variant: :outline, class: "gap-6", id: "tg" })).at_css("[data-slot=toggle-group]")

    assert_equal "radiogroup", root["role"]
    assert_equal "ltr", root["dir"]
    assert_equal "0", root["tabindex"]
    assert_equal "outline: none; --gap: 0;", root["style"]
    assert_equal "outline", root["data-variant"]
    assert_equal "0", root["data-spacing"]
    assert_nil root["data-size"]
    assert_includes root["class"], "gap-6"
    assert_equal "tg", root["id"]
  end

  test "multiple root is a toolbar and spacing is formatted like javascript" do
    root = fragment(group(root: { type: "multiple", spacing: 2.0 })).at_css("[data-slot=toggle-group]")

    assert_equal "toolbar", root["role"]
    assert_equal "2", root["data-spacing"]
  end

  test "type is required and validated" do
    assert_raises(ArgumentError) { group(root: {}) }
    assert_raises(ArgumentError) { group(root: { type: "triple" }) }
    assert_raises(ArgumentError) { group(root: { type: "single", default_value: [ "a" ] }) }
    assert_raises(ArgumentError) { group(root: { type: "multiple", default_value: "a" }) }
  end

  test "single items are radios and the default value presses one" do
    items = fragment(group(root: { type: "single", default_value: "b" })).css("[data-slot=toggle-group-item]")

    assert_equal(%w[radio radio], items.map { |i| i["role"] })
    assert_equal(%w[false true], items.map { |i| i["aria-checked"] })
    assert_equal(%w[off on], items.map { |i| i["data-state"] })
    assert_equal(%w[-1 -1], items.map { |i| i["tabindex"] })
    assert_nil items.first["aria-pressed"]
    assert_nil items.first["value"]
  end

  test "multiple items expose aria-pressed" do
    items = fragment(group(root: { type: "multiple", default_value: %w[a b] })).css("[data-slot=toggle-group-item]")

    assert_equal(%w[true true], items.map { |i| i["aria-pressed"] })
    assert_nil items.first["role"]
  end

  test "group variant and size win over the item" do
    item = fragment(group(root: { type: "single", variant: "outline" },
                          item: { variant: "default", size: :sm })).at_css("[data-slot=toggle-group-item]")

    assert_equal "outline", item["data-variant"]
    assert_equal "sm", item["data-size"]
    assert_includes item["class"], "border-input"
  end

  test "disabled group disables items and the root tab stop" do
    html = fragment(group(root: { type: "single", disabled: true }))

    assert_equal "-1", html.at_css("[data-slot=toggle-group]")["tabindex"]
    assert(html.css("[data-slot=toggle-group-item]").all? { |i| i["data-disabled"] == "" && i.key?("disabled") })
  end

  test "roving_focus false drops roving attributes" do
    html = fragment(group(root: { type: "single", roving_focus: false }))
    root = html.at_css("[data-slot=toggle-group]")

    assert_nil root["tabindex"]
    assert_equal "--gap: 0;", root["style"]
    assert_nil html.at_css("[data-slot=toggle-group-item]")["tabindex"]
  end

  test "item outside a group raises" do
    assert_raises(ArgumentError) { render_view { render ToggleGroup::Item.new(value: "a") } }
  end

  test "as_child renders the root on the given tag" do
    html = render_view { render(ToggleGroup.new(type: "single", as_child: :section)) { } }

    assert fragment(html).at_css("section[data-slot=toggle-group]")
  end

  # Documented deviation (deviations/toggle-group.json): React drops every root attribute with as_child (the Slot clones
  # the Context.Provider); the port keeps them on the caller's element because the Stimulus controller lives there.
  test "as_child keeps every root attribute and the controller on the caller's element (deviation from React)" do
    html = render_view do
      render(ToggleGroup.new(type: "single", variant: :outline, as_child: :section, class: "gap-6", "aria-label": "Align")) do
        render(ToggleGroup::Item.new(value: "a")) { "A" }
      end
    end
    root = fragment(html).at_css("section")

    assert_equal "toggle-group", root["data-slot"]
    assert_equal "radiogroup", root["role"]
    assert_equal "Align", root["aria-label"]
    assert_equal "outline", root["data-variant"]
    assert_includes root["class"], "gap-6"
    assert_includes root["class"], "group/toggle-group"
    assert_includes root["data-controller"].to_s, "shadcn--toggle-group"
    assert root.at_css("[data-slot=toggle-group-item]"), "items render inside the caller's element"
    assert_equal 1, fragment(html).css("[data-slot=toggle-group]").size, "no wrapper element is added"
  end

  test "every DX helper renders the same HTML as the explicit class call" do
    helper = render_view do
      render(ToggleGroup.new(type: "single")) { |toggle_group| toggle_group.item(value: "a") { "x" } }
    end
    explicit = render_view do
      render(ToggleGroup.new(type: "single")) { render(ToggleGroup::Item.new(value: "a")) { "x" } }
    end

    assert_equal explicit, helper
    assert_respond_to ToggleGroup.new(type: "single"), :item
  end
end

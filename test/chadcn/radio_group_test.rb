# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::RadioGroupTest < Chadcn::TestCase
  RadioGroup = Chadcn::RadioGroup

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def group(root: {}, item: {})
    render_view do
      render(RadioGroup.new(**root)) do
        render(RadioGroup::Item.new(value: "a", **item))
        render(RadioGroup::Item.new(value: "b"))
      end
    end
  end

  test "root renders radix attributes, slot and merged class" do
    root = fragment(group(root: { class: "gap-6", id: "rg", aria: { label: "Plan" } })).at_css("[data-slot=radio-group]")

    assert_equal "radiogroup", root["role"]
    assert_equal "false", root["aria-required"]
    assert_equal "ltr", root["dir"]
    assert_equal "0", root["tabindex"]
    assert_equal "outline: none;", root["style"]
    assert_equal "grid gap-6", root["class"]
    assert_equal "rg", root["id"]
    assert_equal "Plan", root["aria-label"]
    assert_nil root["aria-orientation"]
  end

  test "orientation, required and disabled" do
    root = fragment(group(root: { orientation: :horizontal, required: true, disabled: true })).at_css("[data-slot=radio-group]")

    assert_equal "horizontal", root["aria-orientation"]
    assert_equal "horizontal", root["data-orientation"]
    assert_equal "true", root["aria-required"]
    assert_equal "", root["data-disabled"]
    assert_equal "-1", root["tabindex"]
  end

  test "default value checks the item and renders the indicator" do
    items = fragment(group(root: { default_value: "b" })).css("[data-slot=radio-group-item]")

    assert_equal(%w[false true], items.map { |i| i["aria-checked"] })
    assert_equal(%w[unchecked checked], items.map { |i| i["data-state"] })
    assert_equal 1, items.last.css("[data-slot=radio-group-indicator]").size
    assert_empty items.first.css("[data-slot=radio-group-indicator]")
    assert_equal([ "-1", "-1" ], items.map { |i| i["tabindex"] })
  end

  test "item attrs, class merge, disabled and bubble input" do
    html = group(root: { name: "plan", required: true }, item: { class: "size-6", id: "ia", disabled: true, aria: { invalid: true } })
    item = fragment(html).at_css("#ia")

    assert_includes item["class"], "size-6"
    refute_includes item["class"].split, "size-4"
    assert_equal "", item["data-disabled"]
    assert item.key?("disabled")
    assert_equal "true", item["aria-invalid"]
    assert_equal "", item["data-radix-collection-item"]
    assert_includes item["data-action"], "click->chadcn--radio-group#select"
    bubble = item.next_element

    assert_equal "radio", bubble["type"]
    assert_equal "plan", bubble["name"]
    assert bubble.key?("required")
    assert bubble.key?("disabled")
  end

  test "item outside a group raises" do
    assert_raises(ArgumentError) { render_view { render(RadioGroup::Item.new(value: "a")) } }
  end

  test "dir resolves from the direction provider and a local dir wins" do
    provided = render_view { render(Chadcn::Direction::Provider.new(dir: "rtl")) { render(RadioGroup.new) } }
    local = render_view { render(Chadcn::Direction::Provider.new(dir: "rtl")) { render(RadioGroup.new(dir: "ltr")) } }

    assert_equal "rtl", fragment(provided).at_css("[data-slot=radio-group]")["dir"]
    assert_equal "ltr", fragment(local).at_css("[data-slot=radio-group]")["dir"]
  end

  test "as_child renders the slotted tag" do
    html = render_view { render(RadioGroup.new(as_child: :fieldset, default_value: "a")) { render(RadioGroup::Item.new(value: "a")) } }

    assert fragment(html).at_css("fieldset[data-slot=radio-group][role=radiogroup]")
  end

  test "the item helper renders the same HTML as the explicit class call" do
    helpers = render_view do
      render(RadioGroup.new(default_value: "a")) { |rg| rg.item(value: "a", class: "x") }
    end
    explicit = render_view do
      render(RadioGroup.new(default_value: "a")) { render(RadioGroup::Item.new(value: "a", class: "x")) }
    end

    assert_equal explicit, helpers
  end

  test "constant tables and unknown options" do
    assert_equal %w[horizontal vertical], RadioGroup::ORIENTATIONS
    assert_equal %w[ltr rtl], RadioGroup::DIRECTIONS
    assert_raises(ArgumentError) { group(root: { orientation: "diagonal" }) }
    assert_raises(ArgumentError) { group(root: { dir: "up" }) }
  end

  test "controlled value, name and form reach the bubble inputs" do
    doc = fragment(group(root: { value: "b", name: "plan", form: "f1", required: true }))

    assert_equal "true", doc.at_css("[data-slot=radio-group]")["data-chadcn--radio-group-controlled-value"]
    assert_equal "checked", doc.at_css("button[value=b]")["data-state"]
    assert_equal(%w[plan plan], doc.css("input").map { |i| i["name"] })
    assert_equal(%w[f1 f1], doc.css("input").map { |i| i["form"] })
  end
end

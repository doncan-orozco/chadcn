# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::SelectTest < Phlex::Shadcn::TestCase
  Select = Phlex::Shadcn::Select

  HELPERS = {
    trigger: Select::Trigger, value: Select::Value, content: Select::Content, group: Select::Group, label: Select::Label,
    item: Select::Item, separator: Select::Separator, scroll_up_button: Select::ScrollUpButton,
    scroll_down_button: Select::ScrollDownButton
  }.freeze

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def select(root: {}, trigger: {}, content: {})
    render_view do
      render(Select.new(**root)) do
        render(Select::Trigger.new(**trigger)) { render(Select::Value.new(placeholder: "Pick", class: "dropped")) }
        render(Select::Content.new(**content)) do
          render(Select::Group.new) do
            render(Select::Label.new) { "Fruits" }
            render(Select::Item.new(value: "apple")) { "Apple" }
            render(Select::Item.new(value: "banana", disabled: true)) { "Banana" }
          end
        end
      end
    end
  end

  test "closed select shows the placeholder and ships the content in an inert template" do
    doc = fragment(select)
    trigger = doc.at_css("[data-slot=select-trigger]")

    assert_equal "combobox", trigger["role"]
    assert_equal "false", trigger["aria-expanded"]
    assert_equal "default", trigger["data-size"]
    assert_equal "", trigger["data-placeholder"]
    assert_nil trigger["aria-controls"]
    assert_equal "Pick", trigger.at_css("[data-slot=select-value]").text
    assert_nil trigger.at_css("[data-slot=select-value]")["class"]
    assert doc.at_css("template [data-slot=select-content][role=listbox]")
  end

  test "a known value renders the item children in Value and marks the item" do
    doc = fragment(select(root: { default_value: "apple" }))

    assert_equal "Apple", doc.at_css("[data-slot=select-value]").text
    assert_nil doc.at_css("[data-slot=select-trigger]")["data-placeholder"]
    item = doc.at_css("template [data-slot=select-item]")

    assert_equal "checked", item["data-state"]
    assert item.at_css("[data-slot=select-item-indicator] svg")
  end

  test "sizes, disabled items and merged classes" do
    doc = fragment(select(trigger: { size: :sm, class: "w-40" }))

    assert_equal "sm", doc.at_css("[data-slot=select-trigger]")["data-size"]
    assert_includes doc.at_css("[data-slot=select-trigger]")["class"], "w-40"
    disabled = doc.css("template [data-slot=select-item]").last

    assert_equal "true", disabled["aria-disabled"]
    assert_nil disabled["tabindex"]
  end

  test "popper content gets the popper tokens" do
    content = fragment(select(content: { position: :popper })).at_css("template [data-slot=select-content]")

    assert_includes content["class"], "data-[side=bottom]:translate-y-1"
    assert_includes content["style"], "--radix-select-trigger-height"
  end

  test "name renders the native select with one option per item" do
    options = fragment(select(root: { name: "fruit" })).css("select[aria-hidden=true] option")

    assert_equal([ "", "apple", "banana" ], options.map { |option| option["value"] })
  end

  test "as_child is rejected on trigger and item" do
    assert_raises(ArgumentError) { Select::Trigger.new(as_child: true) }
    assert_raises(ArgumentError) { Select::Item.new(value: "a", as_child: true) }
  end

  test "every DX helper exists on the root and renders like the explicit call" do
    root = Select.new

    HELPERS.each_key { |helper| assert_respond_to root, helper }

    explicit = render_view { render(Select.new(value: "a")) { render(Select::Content.new) { render(Select::Separator.new(class: "x")) } } }
    helped = render_view { render(Select.new(value: "a")) { |s| s.content { |_| render(Select::Separator.new(class: "x")) } } }

    assert_equal explicit, helped
  end

  test "dir resolves from the direction provider and a local dir wins" do
    provided = render_view { render(Phlex::Shadcn::Direction::Provider.new(dir: "rtl")) { render(Select.new) { render(Select::Trigger.new) { "x" } } } }
    local = render_view { render(Phlex::Shadcn::Direction::Provider.new(dir: "rtl")) { render(Select.new(dir: "ltr")) { render(Select::Trigger.new) { "x" } } } }

    assert_equal "rtl", fragment(provided).at_css("[data-slot=select-trigger]")["dir"]
    assert_equal "ltr", fragment(local).at_css("[data-slot=select-trigger]")["dir"]
  end
end

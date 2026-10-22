# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::SelectTest < Chadcn::TestCase
  Select = Chadcn::Select

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

  test "root renders its block twice" do
    calls = 0
    render_view { render(Select.new) { calls += 1 } }

    assert_equal 2, calls
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

    explicit = render_view do
      render(Select.new(value: "a")) do
        render(Select::Trigger.new(class: "t")) { render(Select::Value.new(placeholder: "Pick")) }
        render(Select::Content.new(class: "c")) do
          render(Select::ScrollUpButton.new(class: "u"))
          render(Select::Group.new(class: "g")) do
            render(Select::Label.new(class: "l")) { "L" }
            render(Select::Item.new(value: "a", class: "i")) { "A" }
          end
          render(Select::Separator.new(class: "x"))
          render(Select::ScrollDownButton.new(class: "d"))
        end
      end
    end
    helped = render_view do
      render(Select.new(value: "a")) do |s|
        s.trigger(class: "t") { s.value(placeholder: "Pick") }
        s.content(class: "c") do
          s.scroll_up_button(class: "u")
          s.group(class: "g") do
            s.label(class: "l") { "L" }
            s.item(value: "a", class: "i") { "A" }
          end
          s.separator(class: "x")
          s.scroll_down_button(class: "d")
        end
      end
    end

    assert_equal explicit, helped
    assert(HELPERS.keys.all? { |helper| helped.include?("select-#{helper.to_s.tr('_', '-')}") })
  end

  test "dir resolves from the direction provider and a local dir wins" do
    provided = render_view { render(Chadcn::Direction::Provider.new(dir: "rtl")) { render(Select.new) { render(Select::Trigger.new) { "x" } } } }
    local = render_view { render(Chadcn::Direction::Provider.new(dir: "rtl")) { render(Select.new(dir: "ltr")) { render(Select::Trigger.new) { "x" } } } }

    assert_equal "rtl", fragment(provided).at_css("[data-slot=select-trigger]")["dir"]
    assert_equal "ltr", fragment(local).at_css("[data-slot=select-trigger]")["dir"]
  end

  test "the constants are used in the rendered markup" do
    doc = fragment(select(root: { name: "fruit", form: "f1" }, content: { position: :popper }))
    content = doc.at_css("template [data-slot=select-content]")
    viewport = doc.at_css("template [data-radix-select-viewport]")

    assert_equal Select::Trigger::VISUALLY_HIDDEN, doc.at_css("select[aria-hidden=true]")["style"]
    assert_includes content["style"], Select::Content::POPPER_STYLE_VARS.map { |name, value| "#{name}: #{value}" }.join("; ")
    assert_equal Select::Content::VIEWPORT_STYLE, viewport["style"]
    assert_includes viewport["class"], Select::Content::VIEWPORT_CLASSES
    assert_includes doc.at_css("template style").text, Select::Content::VIEWPORT_CSS
    assert_includes doc.at_css("template [data-slot=select-label]")["class"], Select::Label::CLASSES
  end

  test "an unsupported dir is ignored and the direction falls back to ltr" do
    trigger = fragment(select(root: { dir: "up" })).at_css("[data-slot=select-trigger]")

    assert_equal "ltr", trigger["dir"]
    assert_equal "ltr", trigger["data-chadcn--select-dir-value"]
  end

  test "an unknown content position raises at construction" do
    error = assert_raises(ArgumentError) { Select::Content.new(position: "floating") }

    assert_equal "position must be one of item-aligned, popper", error.message
    popper = render_view { render(Select.new) { render(Select::Content.new(position: :popper)) } }

    assert_equal "popper", JSON.parse(fragment(popper).at_css("template")["data-options"])["position"]
  end

  test "parts raise at render, not at construction, when used outside a Select" do
    [ Select::Trigger, Select::Value, Select::Content, Select::Group ].each do |part|
      part.new
      error = assert_raises(ArgumentError) { render_view { render(part.new) { "x" } } }

      assert_equal "#{part.name} must be used within Select", error.message
    end
    assert_raises(ArgumentError) { render_view { render(Select::Item.new(value: "a")) { "x" } } }
  end

  test "a label outside a group raises at render" do
    error = assert_raises(ArgumentError) { render_view { render(Select.new) { render(Select::Label.new) { "x" } } } }

    assert_equal "Chadcn::Select::Label must be used within a Group", error.message
  end

  test "item requires value" do
    assert_raises(ArgumentError) { Select::Item.new }
  end

  test "controlled value and open are mirrored into the trigger values" do
    trigger = fragment(select(root: { value: :banana, open: true })).at_css("[data-slot=select-trigger]")

    assert_equal "true", trigger["data-chadcn--select-controlled-open-value"]
    assert_equal "true", trigger["data-chadcn--select-controlled-value-value"]
    assert_equal "banana", trigger["data-chadcn--select-value-value"]
    assert_equal "true", trigger["aria-expanded"]
    assert_equal "open", trigger["data-state"]
    assert_match(/\Aselect-\d+-content\z/, trigger["aria-controls"])
    assert_equal trigger["aria-controls"], trigger["data-chadcn--select-content-id-value"]
  end

  test "uncontrolled defaults are not marked controlled and default_open opens" do
    trigger = fragment(select(root: { default_value: "apple", default_open: true })).at_css("[data-slot=select-trigger]")

    assert_equal "false", trigger["data-chadcn--select-controlled-open-value"]
    assert_equal "false", trigger["data-chadcn--select-controlled-value-value"]
    assert_equal "apple", trigger["data-chadcn--select-value-value"]
    assert_equal "open", trigger["data-state"]
  end

  test "id sets the base of the generated ids" do
    doc = fragment(select(root: { id: "fruit", default_open: true }))

    assert_equal "fruit-content", doc.at_css("[data-slot=select-trigger]")["aria-controls"]
    assert_equal "fruit-content", doc.at_css("template [data-slot=select-content]")["id"]
    assert_equal "fruit-content", doc.at_css("template")["data-chadcn--select-template"]
    assert_equal "fruit-content", doc.at_css("[data-slot=select-trigger]")["data-chadcn--select-content-id-value"]
  end

  test "disabled on the root or on the trigger disables the button" do
    assert fragment(select(root: { disabled: true })).at_css("[data-slot=select-trigger]")["disabled"]
    on_trigger = fragment(select(trigger: { disabled: true })).at_css("[data-slot=select-trigger]")

    assert on_trigger.key?("disabled")
    assert_equal "", on_trigger["data-disabled"]
    refute fragment(select).at_css("[data-slot=select-trigger]").key?("disabled")
    assert_nil fragment(select).at_css("[data-slot=select-trigger]")["data-disabled"]
  end

  test "form, autocomplete, required and disabled reach the hidden native select" do
    native = fragment(select(root: { form: "f1", auto_complete: "off", required: true, disabled: true })).at_css("select[aria-hidden=true]")

    assert_equal "f1", native["form"]
    assert_equal "off", native["autocomplete"]
    assert native.key?("required")
    assert native.key?("disabled")
    assert_equal "-1", native["tabindex"]
  end

  test "required false renders aria-required false on the trigger and nil omits it" do
    assert_equal "false", fragment(select(root: { required: false })).at_css("[data-slot=select-trigger]")["aria-required"]
    refute fragment(select(root: { required: nil })).at_css("[data-slot=select-trigger]").key?("aria-required")
  end

  test "no native select is rendered without name or form and the selected option is marked" do
    assert_nil fragment(select).at_css("select")
    options = fragment(select(root: { name: "fruit", default_value: "banana" })).css("select option")

    selected = options.select { |option| option.key?("selected") }

    assert_equal([ "banana" ], selected.map { |option| option["value"] })
    assert options.find { |option| option["value"] == "banana" }.key?("disabled")
  end

  test "trigger yields its block before the chevron icon and merges data" do
    html = render_view do
      render(Select.new) { render(Select::Trigger.new(data: { test: "t" })) { span { "inner" } } }
    end
    trigger = fragment(html).at_css("button")

    assert_equal "t", trigger["data-test"]
    assert_equal "chadcn--select", trigger["data-controller"]
    assert_equal %w[span svg], trigger.element_children.map(&:name)
  end

  test "value block replaces the copy of the selected item and drops class and style" do
    html = render_view do
      render(Select.new(default_value: "a")) do
        render(Select::Trigger.new) { render(Select::Value.new(class: "x", style: "color: red", id: "v")) { "Custom" } }
        render(Select::Content.new) { render(Select::Item.new(value: "a")) { "Item A" } }
      end
    end
    value = fragment(html).at_css("button [data-slot=select-value]")

    assert_equal "Custom", value.text
    assert_equal "v", value["id"]
    assert_nil value["class"]
    assert_equal "pointer-events: none;", value["style"]
  end

  test "item text_value, value and class are written to the option element" do
    html = render_view do
      render(Select.new) { render(Select::Content.new) { render(Select::Item.new(value: :one, text_value: "Uno", class: "extra")) { "One" } } }
    end
    item = fragment(html).at_css("template [data-slot=select-item]")

    assert_equal "one", item["data-chadcn--select-value"]
    assert_equal "Uno", item["data-chadcn--select-text-value"]
    assert_includes item["class"], "extra"
    assert_equal "option", item["role"]
    assert_equal "unchecked", item["data-state"]
    assert_equal "-1", item["tabindex"]
    assert_equal "One", item.at_css("span:last-child").text
  end

  test "the hidden native option text is the block text, whatever text_value says" do
    html = render_view do
      render(Select.new(name: "n", form: "f")) do
        render(Select::Trigger.new)
        render(Select::Content.new) do
          render(Select::Item.new(value: "one", text_value: "Uno")) { "One" }
          render(Select::Item.new(value: "two")) { "Two" }
        end
      end
    end
    doc = fragment(html)

    assert_equal %w[One Two], doc.css("select[aria-hidden=true] option").reject { |option| option["value"].empty? }.map(&:text)
    typeahead = doc.css("template [data-slot=select-item]").filter_map { |item| item["data-chadcn--select-text-value"] }

    assert_equal %w[Uno], typeahead
  end

  test "content options are serialized for the controller and attrs merge" do
    html = select(content: { side: :top, side_offset: 4, sticky: :always, force_mount: true, class: "w-40", style: "color: red", data: { x: "1" } })
    template = fragment(html).at_css("template")
    options = JSON.parse(template["data-options"])
    content = template.at_css("[data-slot=select-content]")

    assert_equal "item-aligned", options["position"]
    assert_equal "top", options["side"]
    assert_equal 4, options["sideOffset"]
    assert_equal "always", options["sticky"]
    assert_equal 10, options["collisionPadding"]
    assert options["forceMount"]
    assert_includes content["class"], "w-40"
    assert_includes content["style"], "color: red"
    assert_equal "1", content["data-x"]
    assert_equal "open", content["data-state"]
    assert_nil content["class"][/translate-y-1/]
  end

  test "content renders the viewport and both scroll buttons" do
    template = fragment(select).at_css("template")

    assert template.at_css("[data-slot=select-scroll-up-button]")
    assert template.at_css("[data-slot=select-scroll-down-button]")
    assert template.at_css("[data-radix-select-viewport][role=presentation]")
    assert_includes template.at_css("style").text, "scrollbar-width:none"
  end

  test "scroll buttons render a chevron, are aria-hidden and merge class" do
    html = render_view do
      render(Select::ScrollUpButton.new(class: "up"))
      render(Select::ScrollDownButton.new(class: "down", data: { x: "1" }))
    end
    up, down = fragment(html).css("div")

    assert_equal "true", up["aria-hidden"]
    assert_includes up["class"], "up"
    assert_includes down["class"], "down"
    assert_equal "1", down["data-x"]
    assert up.at_css("svg")
    assert down.at_css("svg")
  end

  test "group, label and separator render with their slots and the label points the group at its id" do
    doc = fragment(select)
    group = doc.at_css("template [data-slot=select-group]")
    label = doc.at_css("template [data-slot=select-label]")

    assert_equal "group", group["role"]
    assert_equal label["id"], group["aria-labelledby"]
    assert_equal "Fruits", label.text

    separator = fragment(render_view { render(Select.new) { render(Select::Separator.new(class: "my-4")) } }).at_css("[data-slot=select-separator]")

    assert_equal "true", separator["aria-hidden"]
    assert_includes separator["class"], "my-4"
  end

  test "as_child on group, label and separator renders the given tag" do
    html = render_view do
      render(Select.new) do
        render(Select::Group.new(as_child: :section)) do
          render(Select::Label.new(as_child: "h4")) { "L" }
        end
        render(Select::Separator.new(as_child: :hr))
      end
    end
    doc = fragment(html)

    assert_equal "section", doc.at_css("[data-slot=select-group]").name
    assert_equal "h4", doc.at_css("[data-slot=select-label]").name
    assert_equal "hr", doc.at_css("[data-slot=select-separator]").name
  end

  test "as_child false renders a div" do
    html = render_view { render(Select.new) { render(Select::Separator.new(as_child: false)) } }

    assert_equal "div", fragment(html).at_css("[data-slot=select-separator]").name
  end

  test "the generated item and label helpers render like the explicit parts" do
    explicit = render_view do
      render(Select.new) do
        render(Select::Group.new) do
          render(Select::Label.new(class: "l")) { "L" }
          render(Select::Item.new(value: "a")) { "A" }
        end
      end
    end
    helped = render_view do
      render(Select.new) do |s|
        s.group do
          s.label(class: "l") { "L" }
          s.item(value: "a") { "A" }
        end
      end
    end

    assert_equal explicit, helped
  end
end

# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::AccordionTest < Chadcn::TestCase
  Accordion = Chadcn::Accordion

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def accordion(root: {}, item: {}, trigger: {}, content: {})
    render_view do
      render(Accordion.new(**root)) do
        render(Accordion::Item.new(value: "a", **item)) do
          render(Accordion::Trigger.new(**trigger)) { "One" }
          render(Accordion::Content.new(**content)) { "Body one" }
        end
        render(Accordion::Item.new(value: "b")) do
          render(Accordion::Trigger.new) { "Two" }
          render(Accordion::Content.new) { "Body two" }
        end
      end
    end
  end

  test "root renders slot, orientation and merged class" do
    root = fragment(accordion(root: { class: "w-full", id: "acc", aria: { label: "Q" } })).at_css("[data-slot=accordion]")

    assert_equal "vertical", root["data-orientation"]
    assert_equal "w-full", root["class"]
    assert_equal "acc", root["id"]
    assert_equal "Q", root["aria-label"]
    assert_nil root["role"]
  end

  test "default value opens an item with its wiring and chevron" do
    doc = fragment(accordion(root: { default_value: "a" }))
    item, other = doc.css("[data-slot=accordion-item]")
    button = item.at_css("button")
    region = item.at_css("[data-slot=accordion-content]")

    assert_equal "open", item["data-state"]
    assert_equal "h3", button.parent.name
    assert_equal "true", button["aria-expanded"]
    assert_equal region["id"], button["aria-controls"]
    assert_equal button["id"], region["aria-labelledby"]
    assert_equal "true", button["aria-disabled"]
    assert_nil region["hidden"]
    assert_equal "pt-0 pb-4", region.at_css("> div")["class"]
    assert_includes region["style"], "transition-duration: 0s"
    assert button.at_css("svg.lucide-chevron-down")

    closed = other.at_css("[data-slot=accordion-content]")

    assert_equal "closed", other["data-state"]
    assert_equal "", closed["hidden"]
    assert_nil other.at_css("button")["aria-controls"]
    assert closed.at_css("template[data-chadcn--accordion-target=body]")
  end

  test "collapsible and multiple drop aria-disabled" do
    assert_nil fragment(accordion(root: { default_value: "a", collapsible: true })).at_css("button")["aria-disabled"]
    assert_nil fragment(accordion(root: { type: :multiple, default_value: %w[a] })).at_css("button")["aria-disabled"]
  end

  test "disabled flows from root and item" do
    from_item = fragment(accordion(item: { disabled: true })).at_css("[data-slot=accordion-item]")

    assert_equal "", from_item["data-disabled"]
    assert_equal "", from_item.at_css("button")["disabled"]

    doc = fragment(accordion(root: { disabled: true }))
    buttons = doc.css("[data-slot=accordion-trigger]")

    assert_equal 2, buttons.size
    assert(buttons.all? { |button| button.key?("disabled") })
    assert_equal 2, doc.css("[data-slot=accordion-item]").size
    assert(doc.css("[data-slot=accordion-item]").all? { |item| item["data-disabled"] == "" })
  end

  test "class goes to the inner div and passthrough attrs to their parts" do
    doc = fragment(accordion(item: { class: "x-item" }, trigger: { class: "x-trigger", data: { foo: "1" } },
                             content: { class: "x-inner", style: "color: red", id: "c1" }, root: { default_value: "a" }))
    item = doc.at_css("[data-slot=accordion-item]")
    region = doc.at_css("[data-slot=accordion-content]")

    assert_includes item["class"], "x-item"
    assert_includes item["class"], "border-b"
    assert_includes doc.at_css("button")["class"], "x-trigger"
    assert_equal "1", doc.at_css("button")["data-foo"]
    assert_equal "c1", region["id"]
    assert_includes region["class"], "overflow-hidden"
    refute_includes region["class"], "x-inner"
    assert_includes region.at_css("> div")["class"], "x-inner"
    assert_includes region["style"], "color: red"
  end

  test "as_child renders the root onto the given element" do
    html = render_view do
      render(Accordion.new(as_child: :section, class: "s")) do
        render(Accordion::Item.new(value: "a")) { "x" }
      end
    end
    root = fragment(html).at_css("section")

    assert_equal "accordion", root["data-slot"]
    assert_equal "s", root["class"]
  end

  test "every DX helper renders the same HTML as the explicit class call" do
    helpers = render_view do
      render(Accordion.new(default_value: "a")) do |acc|
        acc.item(value: "a") do
          acc.trigger(class: "t") { "One" }
          acc.content(class: "c") { "Body" }
        end
      end
    end
    explicit = render_view do
      render(Accordion.new(default_value: "a")) do
        render(Accordion::Item.new(value: "a")) do
          render(Accordion::Trigger.new(class: "t")) { "One" }
          render(Accordion::Content.new(class: "c")) { "Body" }
        end
      end
    end

    assert_equal explicit, helpers
    %i[item trigger content].each { |name| assert_includes Accordion.public_instance_methods(false), name }
  end

  test "dir resolves from the direction provider and a local dir wins" do
    provided = render_view { render(Chadcn::Direction::Provider.new(dir: "rtl")) { render(Accordion.new) } }
    local = render_view { render(Chadcn::Direction::Provider.new(dir: "rtl")) { render(Accordion.new(dir: "ltr")) } }

    assert_equal "rtl", fragment(provided).at_css("[data-slot=accordion]")["data-chadcn--accordion-dir-value"]
    assert_equal "ltr", fragment(local).at_css("[data-slot=accordion]")["data-chadcn--accordion-dir-value"]
  end

  test "content force_mount renders a closed body and root orientation reaches items" do
    doc = fragment(accordion(root: { orientation: "horizontal" }, content: { force_mount: true }))
    region = doc.at_css("[data-slot=accordion-content]")

    assert_equal "horizontal", doc.at_css("[data-slot=accordion-item]")["data-orientation"]
    assert_equal "true", region["data-chadcn--accordion-force-mount"]
    assert_includes region.text, "Body one"
    assert_nil region.at_css("template")
  end

  test "controlled value and type reach the controller values" do
    root = fragment(accordion(root: { type: "multiple", value: %w[a b] })).at_css("[data-slot=accordion]")

    assert_equal "multiple", root["data-chadcn--accordion-type-value"]
    assert_equal "true", root["data-chadcn--accordion-controlled-value"]
    states = fragment(accordion(root: { type: "multiple", value: %w[a b] })).css("[data-slot=accordion-item]").map { |i| i["data-state"] }

    assert_equal %w[open open], states
  end
end

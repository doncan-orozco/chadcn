# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::CollapsibleTest < Chadcn::TestCase
  Collapsible = Chadcn::Collapsible

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def collapsible(root: {}, trigger: {}, content: {})
    render_view do
      render(Collapsible.new(**root)) do
        render(Collapsible::Trigger.new(**trigger)) { "Toggle" }
        render(Collapsible::Content.new(**content)) { "Body" }
      end
    end
  end

  test "closed root, trigger and content" do
    doc = fragment(collapsible(root: { class: "w-80", id: "c" }, trigger: { class: "t" }, content: { class: "k" }))
    root = doc.at_css("[data-slot=collapsible]")
    button = doc.at_css("[data-slot=collapsible-trigger]")
    body = doc.at_css("[data-slot=collapsible-content]")

    assert_equal "closed", root["data-state"]
    assert_equal "w-80", root["class"]
    assert_equal "c", root["id"]
    assert_equal "button", button["type"]
    assert_equal "false", button["aria-expanded"]
    assert_nil button["aria-controls"]
    assert_equal "t", button["class"]
    assert_equal "k", body["class"]
    assert_equal "closed", body["data-state"]
    assert_equal "", body["hidden"]
    assert body.at_css("template")
  end

  test "default open renders the body with the wiring" do
    doc = fragment(collapsible(root: { default_open: true }))
    button = doc.at_css("button")
    body = doc.at_css("[data-slot=collapsible-content]")

    assert_equal "open", doc.at_css("[data-slot=collapsible]")["data-state"]
    assert_equal "true", button["aria-expanded"]
    assert_equal body["id"], button["aria-controls"]
    assert_nil body["hidden"]
    assert_includes body["style"], "animation-name: none"
    assert_includes body.text, "Body"
  end

  test "disabled and passthrough attrs" do
    doc = fragment(collapsible(root: { disabled: true }, trigger: { type: "submit", aria: { label: "x" } }, content: { id: "mine" }))
    button = doc.at_css("button")

    assert_equal "", button["disabled"]
    assert_equal "", button["data-disabled"]
    assert_equal "", doc.at_css("[data-slot=collapsible]")["data-disabled"]
    assert_equal "submit", button["type"]
    assert_equal "x", button["aria-label"]
    assert_equal "mine", doc.at_css("[data-slot=collapsible-content]")["id"]
  end

  test "as_child trigger merges onto the child" do
    html = render_view do
      render(Collapsible.new(default_open: true)) do
        render(Collapsible::Trigger.new(as_child: :a, href: "#")) { "Go" }
      end
    end
    link = fragment(html).at_css("a")

    assert_equal "true", link["aria-expanded"]
    assert_equal "#", link["href"]
  end

  test "as_child content is only a template while closed" do
    html = render_view do
      render(Collapsible.new) { render(Collapsible::Content.new(as_child: :section)) { "Body" } }
    end
    doc = fragment(html)

    assert_equal 1, doc.css("section").size
    assert_equal "template", doc.at_css("section").parent.name
    assert_equal "", doc.at_css("section")["style"]
  end

  test "every spec helper renders like the explicit part" do
    helpers = render_view do
      render(Collapsible.new(default_open: true)) do |c|
        c.trigger(class: "t") { "Toggle" }
        c.content { "Body" }
      end
    end
    explicit = render_view do
      render(Collapsible.new(default_open: true)) do
        render(Collapsible::Trigger.new(class: "t")) { "Toggle" }
        render(Collapsible::Content.new) { "Body" }
      end
    end

    assert_equal explicit, helpers
  end

  test "controlled open reaches the controller and force_mount renders a closed body" do
    doc = fragment(collapsible(root: { open: true }))

    assert_equal "true", doc.at_css("[data-slot=collapsible]")["data-chadcn--collapsible-controlled-value"]
    assert_equal "open", doc.at_css("[data-slot=collapsible]")["data-state"]

    forced = fragment(collapsible(content: { force_mount: true })).at_css("[data-slot=collapsible-content]")

    assert_equal "true", forced["data-chadcn--collapsible-force-mount"]
    assert_nil forced.at_css("template")
    assert_includes forced.text, "Body"
  end

  test "id stays on the root and names the content" do
    doc = fragment(collapsible(root: { id: "orders", default_open: true }))

    assert_equal "orders", doc.at_css("[data-slot=collapsible]")["id"]
    assert_equal "orders-content", doc.at_css("[data-slot=collapsible-trigger]")["aria-controls"]
    assert_equal "orders-content", doc.at_css("[data-slot=collapsible-content]")["id"]
    assert_equal "orders-content", doc.at_css("[data-slot=collapsible]")["data-chadcn--collapsible-content-id-value"]
  end

  test "without id the root has no id and the content is collapsible-1-content" do
    doc = fragment(collapsible(root: { default_open: true }))

    assert_nil doc.at_css("[data-slot=collapsible]")["id"]
    assert_equal "collapsible-1-content", doc.at_css("[data-slot=collapsible-content]")["id"]
    assert_equal "collapsible-1-content", doc.at_css("[data-slot=collapsible-trigger]")["aria-controls"]
  end
end

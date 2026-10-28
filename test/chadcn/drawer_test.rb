# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::DrawerTest < Chadcn::TestCase
  Drawer = Chadcn::Drawer

  HELPERS = {
    trigger: Drawer::Trigger, close: Drawer::Close, content: Drawer::Content, header: Drawer::Header,
    footer: Drawer::Footer, title: Drawer::Title, description: Drawer::Description
  }.freeze

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def drawer(root: {}, content: {})
    render_view do
      render(Drawer.new(**root)) do
        render(Drawer::Trigger.new) { "Open" }
        render(Drawer::Content.new(**content)) do
          render(Drawer::Title.new) { "Title" }
          render(Drawer::Description.new) { "Description" }
        end
      end
    end
  end

  def host_of(html) = fragment(html).at_css("[data-controller=chadcn--drawer]")

  test "host carries the controller, no data-slot, and the closed parts live in a template" do
    host = host_of(drawer)

    assert_equal "display: contents", host["style"]
    assert_nil host["data-slot"]
    assert_equal "false", host["data-chadcn--drawer-open-value"]
    assert_equal "bottom", host["data-chadcn--drawer-direction-value"]
    assert host.at_css("template [data-slot=drawer-overlay]")
    assert host.at_css("template [data-slot=drawer-content]")
    assert_equal "drawer-trigger", host.at_css("button")["data-slot"]
  end

  test "content carries the vaul attributes, the direction classes and the drag bar first" do
    content = fragment(drawer(root: { direction: :left })).at_css("[data-slot=drawer-content]")

    assert_equal "left", content["data-vaul-drawer-direction"]
    assert_equal "", content["data-vaul-drawer"]
    assert_equal "false", content["data-vaul-snap-points"]
    assert_equal "false", content["data-vaul-custom-container"]
    assert_equal "true", content["data-vaul-animate"]
    assert_includes content["class"], "data-[vaul-drawer-direction=left]:left-0"
    assert_includes content["class"], "group/drawer-content"
    bar = content.element_children.first

    assert_nil bar["data-slot"]
    assert_includes bar["class"], "w-[100px]"
    assert_equal "drawer-title", content.at_css("h2")["data-slot"]
  end

  test "an unknown direction raises and nil means bottom" do
    error = assert_raises(ArgumentError) { drawer(root: { direction: "middle" }) }

    assert_match(/direction must be one of top, bottom, left, right, got "middle"/, error.message)
    assert_equal "bottom", host_of(drawer(root: { direction: nil }))["data-chadcn--drawer-direction-value"]
  end

  test "default_open renders animate false, a controlled open renders animate true" do
    assert_equal "false", fragment(drawer(root: { default_open: true })).at_css("[data-slot=drawer-content]")["data-vaul-animate"]
    assert_equal "true", fragment(drawer(root: { open: true })).at_css("[data-slot=drawer-content]")["data-vaul-animate"]
  end

  test "snap points are serialized and flag the overlay and content" do
    html = drawer(root: { snap_points: [ 0.5, "300px", 1 ], active_snap_point: 0.5 })
    host = host_of(html)

    assert_equal "[0.5,\"300px\",1]", host["data-chadcn--drawer-snap-points-value"]
    assert_equal "2", host["data-chadcn--drawer-fade-from-index-value"]
    assert_equal "0.5", host["data-chadcn--drawer-active-snap-point-value"]
    assert_equal "true", fragment(html).at_css("[data-slot=drawer-content]")["data-vaul-snap-points"]
    assert_equal "false", fragment(html).at_css("[data-slot=drawer-overlay]")["data-vaul-snap-points-overlay"]
  end

  test "modal false renders no overlay and keeps the Radix modal value true" do
    html = drawer(root: { modal: false })
    host = host_of(html)

    assert_nil fragment(html).at_css("[data-slot=drawer-overlay]")
    assert_equal "true", host["data-chadcn--drawer-modal-value"]
    assert_equal "false", host["data-chadcn--drawer-vaul-modal-value"]
  end

  test "root options land on the host" do
    host = host_of(drawer(root: { dismissible: false, close_threshold: 0.4, should_scale_background: true, container: "#x", class: "x-root" }))

    assert_includes host["class"], "x-root"
    assert_equal "false", host["data-chadcn--drawer-dismissible-value"]
    assert_equal "0.4", host["data-chadcn--drawer-close-threshold-value"]
    assert_equal "true", host["data-chadcn--drawer-should-scale-background-value"]
    assert_equal "#x", host["data-chadcn--drawer-container-value"]
    assert_equal "true", fragment(drawer(root: { container: "#x" })).at_css("[data-slot=drawer-content]")["data-vaul-custom-container"]
  end

  test "content merges class and aria ids, title and description ids come from the root" do
    doc = fragment(drawer(root: { id: "goal" }, content: { class: "w-96", aria: { describedby: "x" } }))
    content = doc.at_css("[data-slot=drawer-content]")

    assert_includes content["class"], "w-96"
    assert_equal "goal", content["id"]
    assert_equal "goal-title", content["aria-labelledby"]
    assert_equal "x goal-description", content["aria-describedby"]
    assert_equal "goal-title", doc.at_css("h2")["id"]
  end

  test "every DX helper renders the same HTML as the explicit class" do
    HELPERS.each do |name, klass|
      explicit = render_view { render(Drawer.new) { render(Drawer::Content.new) { render(klass.new) { "x" } } } }
      helper = render_view { render(Drawer.new) { |d| d.content { d.public_send(name) { "x" } } } }

      assert_equal explicit, helper, name.to_s
    end
  end

  test "parts merge their class and attributes" do
    doc = fragment(render_view do
      render(Drawer.new(default_open: true)) do
        render(Drawer::Content.new(class: "x-content")) do
          render(Drawer::Header.new(class: "x-header")) { "H" }
          render(Drawer::Title.new(class: "x-title")) { "T" }
          render(Drawer::Description.new(class: "x-description")) { "D" }
          render(Drawer::Footer.new(class: "x-footer")) { "F" }
          render(Drawer::Close.new(class: "x-close", id: "c")) { "C" }
        end
      end
    end)

    %w[content header title description footer].each { |slot| assert_includes doc.at_css("[data-slot=drawer-#{slot}]")["class"], "x-#{slot}", slot }
    assert_includes doc.at_css("#c")["class"], "x-close"
  end

  test "parts raise a clear ArgumentError outside the root" do
    %i[Trigger Content Overlay Portal Title Description].each do |part|
      error = assert_raises(ArgumentError, part.to_s) { render_view { render(Drawer.const_get(part).new) } }

      assert_match(/must be used within Drawer/, error.message, part.to_s)
    end
  end

  test "as_child renders the trigger onto the given element" do
    out = render_view { render(Drawer.new) { render(Drawer::Trigger.new(as_child: :a, href: "/x", class: "t")) { "Open" } } }
    trigger = fragment(out).at_css("[data-slot*=trigger]")

    assert_equal "a", trigger.name
    assert_equal "/x", trigger["href"]
    assert_includes trigger["class"], "t"
  end

  test "the trigger controls the content only while open" do
    assert_nil fragment(drawer).at_css("[data-slot=drawer-trigger]")["aria-controls"]
    assert_equal "drawer-1", fragment(drawer(root: { default_open: true })).at_css("[data-slot=drawer-trigger]")["aria-controls"]
  end

  test "a portal container reaches the template options" do
    html = render_view { render(Drawer.new) { render(Drawer::Portal.new(container: "#slot", force_mount: true)) { "x" } } }

    assert_equal({ "forceMount" => true, "container" => "#slot" }, JSON.parse(fragment(html).at_css("template")["data-chadcn--dialog-options"]))
  end
end

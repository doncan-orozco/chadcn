# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::ResizableTest < Chadcn::TestCase
  PanelGroup = Chadcn::Resizable::PanelGroup
  Panel = Chadcn::Resizable::Panel
  Handle = Chadcn::Resizable::Handle

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def group(group: {}, first: {}, handle: {}, second: {})
    fragment(render_view do
      render(PanelGroup.new(**group)) do
        render(Panel.new(**first)) { plain "One" }
        render Handle.new(**handle)
        render(Panel.new(**second)) { plain "Two" }
      end
    end)
  end

  def declarations(element)
    element["style"].split(";").map(&:strip).reject(&:empty?).to_h { |declaration| declaration.split(": ", 2) }
  end

  test "the root renders no element" do
    assert_equal("", render_view { render(Chadcn::Resizable.new) })
  end

  test "group classes, slot, wiring and style" do
    root = group(group: { class: "h-[200px] w-[401px]" }).at_css("[data-slot=resizable-panel-group]")

    assert_equal "flex aria-[orientation=vertical]:flex-col h-[200px] w-[401px]", root["class"]
    assert_equal "true", root["data-group"]
    assert_equal "_r_0_", root["id"]
    assert_equal "_r_0_", root["data-testid"]
    assert_equal "chadcn--resizable", root["data-controller"]
    assert_equal "horizontal", root["data-chadcn--resizable-orientation-value"]
    assert_equal({ "height" => "100%", "width" => "100%", "overflow" => "hidden", "display" => "flex", "flex-direction" => "row",
                   "flex-wrap" => "nowrap", "touch-action" => "pan-y" }, declarations(root))
  end

  test "vertical group, separator preview mode and caller style order" do
    root = group(group: { orientation: :vertical, resize_preview_mode: "separator", style: { height: "150px", display: "block" } })
           .at_css("[data-slot=resizable-panel-group]")

    assert_equal %w[height width overflow position display flex-direction flex-wrap touch-action], declarations(root).keys
    assert_equal "150px", declarations(root)["height"]
    assert_equal "flex", declarations(root)["display"]
    assert_equal "column", declarations(root)["flex-direction"]
    assert_equal "pan-x", declarations(root)["touch-action"]
  end

  test "group rejects unknown options" do
    assert_raises(ArgumentError) { PanelGroup.new(orientation: "diagonal") }
    assert_raises(ArgumentError) { PanelGroup.new(resize_preview_mode: "x") }
  end

  test "ids follow React's useId numbering, explicit ids still consume a number" do
    doc = group(first: { id: "left" })

    assert_equal(%w[_r_0_ left _r_2_ _r_3_], doc.css("[id]").map { |element| element["id"] })
    assert_equal(%w[_r_0_ left _r_2_ _r_3_], doc.css("[data-testid]").map { |element| element["data-testid"] })
  end

  test "panel puts class and style on the inner div and attrs on the outer div" do
    doc = group(first: { class: "bg-muted p-2", style: { padding: "8px" }, "data-foo": "a", title: "Right", disabled: true })
    outer = doc.at_css("[data-slot=resizable-panel]")
    inner = outer.element_children.first

    assert_equal "bg-muted p-2", inner["class"]
    assert_nil outer["class"]
    assert_equal "a", outer["data-foo"]
    assert_equal "Right", outer["title"]
    assert_equal "true", outer["data-disabled"]
    assert_equal "8px", declarations(inner)["padding"]
    assert_equal "pan-y", declarations(inner)["touch-action"]
    assert_equal "One", inner.text
  end

  test "panel flex style before the layout is known" do
    assert_equal "1", declarations(group.at_css("[data-panel]"))["flex-grow"]

    percent = declarations(group(first: { default_size: "30%" }).at_css("[data-panel]"))

    assert_equal "30%", percent["flex-basis"]
    refute percent.key?("flex-grow")
    refute percent.key?("flex-shrink")

    assert_equal "300px", declarations(group(first: { default_size: 300 }).at_css("[data-panel]"))["flex-basis"]
  end

  test "default layout seeds flex-grow by panel id" do
    doc = group(group: { default_layout: { left: 35, "right" => 65 } }, first: { id: "left" }, second: { id: "right" })
    grows = doc.css("[data-panel]").map { |panel| declarations(panel)["flex-grow"] }

    assert_equal %w[35 65], grows
    assert_equal({ "left" => 35, "right" => 65 }, JSON.parse(doc.at_css("[data-controller]")["data-chadcn--resizable-default-layout-value"]))
  end

  test "panel constraints are exported for the controller" do
    panel = group(first: { default_size: "20%", min_size: 100, collapsible: true, id: 7 }).at_css("[data-panel]")
    constraints = JSON.parse(panel["data-chadcn--resizable-constraints"])

    assert_equal({ "defaultSize" => "20%", "minSize" => 100, "maxSize" => "100%", "collapsible" => true, "collapsedSize" => "0%",
                   "disabled" => false, "groupResizeBehavior" => "preserve-relative-size", "id" => "7" }, constraints)
    assert_equal "panel", panel["data-chadcn--resizable-target"]
  end

  test "handle attributes and classes" do
    handle = group(handle: { class: "w-1 bg-primary", "aria-label": "Resize", role: "button", tabindex: 5, style: { flexGrow: "1" } })
             .at_css("[data-slot=resizable-handle]")

    assert_equal "separator", handle["role"]
    assert_equal "0", handle["tabindex"]
    assert_equal "vertical", handle["aria-orientation"]
    assert_equal "inactive", handle["data-separator"]
    assert_equal "Resize", handle["aria-label"]
    assert_includes handle["class"], "w-1 bg-primary"
    refute_includes handle["class"], " w-px "
    assert_equal({ "flex-basis" => "auto", "flex-grow" => "0", "flex-shrink" => "0", "touch-action" => "none" }, declarations(handle))
    assert_equal 0, handle.element_children.size
  end

  test "handle with grip, vertical orientation and disabled state" do
    doc = fragment(render_view do
      render(PanelGroup.new(orientation: "vertical")) do
        render(Panel.new) { plain "One" }
        render Handle.new(with_handle: true, disabled: true, disable_double_click: true)
        render(Panel.new) { plain "Two" }
      end
    end)
    handle = doc.at_css("[data-slot=resizable-handle]")

    assert_equal "horizontal", handle["aria-orientation"]
    assert_equal "true", handle["aria-disabled"]
    assert_equal "disabled", handle["data-separator"]
    assert_nil handle["tabindex"]
    assert_equal "not-allowed", declarations(handle)["cursor"]
    assert_equal "true", handle["data-chadcn--resizable-disable-double-click"]
    assert_equal "z-10 flex h-4 w-3 items-center justify-center rounded-xs border bg-border", handle.at_css("div")["class"]
    assert_includes handle.at_css("svg")["class"], "lucide-grip-vertical size-2.5"
  end

  test "disable_cursor keeps the cursor of a disabled handle" do
    handle = group(group: { disable_cursor: true }, handle: { disabled: true }).at_css("[data-slot=resizable-handle]")

    refute declarations(handle).key?("cursor")
  end

  test "handle preview is an inert template" do
    preview = Class.new(Chadcn::Base) { def view_template = div(class: "ghost") }
    html = render_view do
      render(PanelGroup.new) do
        render(Panel.new) { plain "One" }
        render Handle.new(preview: preview.new)
        render(Panel.new) { plain "Two" }
      end
    end
    template = fragment(html).at_css("[data-slot=resizable-handle] > template")

    assert_equal "preview", template["data-chadcn--resizable-target"]
    assert_includes html, "ghost"
  end

  test "parts outside a group raise" do
    assert_raises(ArgumentError) { render_view { render(Panel.new) } }
    assert_raises(ArgumentError) { render_view { render(Handle.new) } }
  end

  test "caller attrs cannot override what the library sets afterwards" do
    root = group(group: { id: "layout", "data-foo": "g", "data-testid": "x", style: "display: block; overflow: auto" })
           .at_css("[data-slot=resizable-panel-group]")

    assert_equal "layout", root["id"]
    assert_equal "layout", root["data-testid"]
    assert_equal "g", root["data-foo"]
    assert_equal "auto", declarations(root)["overflow"]
    assert_equal "flex", declarations(root)["display"]
  end
end

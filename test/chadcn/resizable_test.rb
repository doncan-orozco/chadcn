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

    %w[flex aria-[orientation=vertical]:flex-col h-[200px] w-[401px]].each { |token| assert_includes root["class"].split, token }
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
    %w[z-10 flex h-4 w-3 items-center justify-center rounded-xs border bg-border].each { |token| assert_includes handle.at_css("div")["class"].split, token }
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

  test "boolean wiring renders true or false, never an empty string" do
    root = group(group: { disabled: nil, disable_cursor: nil }).at_css("[data-controller]")

    assert_equal "false", root["data-chadcn--resizable-disabled-value"]
    assert_equal "false", root["data-chadcn--resizable-disable-cursor-value"]
  end

  test "group wiring carries every value" do
    root = group(group: { disabled: true, resize_preview_mode: :separator, resize_target_minimum_size: { coarse: 30 } }).at_css("[data-controller]")

    assert_equal "true", root["data-chadcn--resizable-disabled-value"]
    assert_equal "separator", root["data-chadcn--resizable-resize-preview-mode-value"]
    assert_equal({ "coarse" => 30, "fine" => 10 }, JSON.parse(root["data-chadcn--resizable-resize-target-minimum-size-value"]))
  end

  test "caller data cannot override the library wiring" do
    root = group(group: { data: { chadcn__resizable_orientation_value: "vertical", "chadcn--resizable-disabled-value": "true" } }).at_css("[data-controller]")
    panel = group(first: { data: { chadcn__resizable_target: "x", chadcn__resizable_constraints: "{}" } }).at_css("[data-panel]")
    handle = group(handle: { data: { chadcn__resizable_target: "x", chadcn__resizable_disable_double_click: "true" } }).at_css("[data-slot=resizable-handle]")

    assert_equal "horizontal", root["data-chadcn--resizable-orientation-value"]
    assert_equal "false", root["data-chadcn--resizable-disabled-value"]
    assert_equal "panel", panel["data-chadcn--resizable-target"]
    assert_includes panel["data-chadcn--resizable-constraints"], "groupResizeBehavior"
    assert_equal "handle", handle["data-chadcn--resizable-target"]
    assert_nil handle["data-chadcn--resizable-disable-double-click"]
  end

  test "panel group_resize_behavior accepts symbols and rejects unknown values" do
    constraints = JSON.parse(group(first: { group_resize_behavior: :preserve_pixel_size }).at_css("[data-panel]")["data-chadcn--resizable-constraints"])

    assert_equal "preserve-pixel-size", constraints["groupResizeBehavior"]
    assert_raises(ArgumentError) { Panel.new(group_resize_behavior: "nope") }
  end

  test "panel booleans are coerced once" do
    panel = group(first: { collapsible: nil, disabled: 1 }).at_css("[data-panel]")
    constraints = JSON.parse(panel["data-chadcn--resizable-constraints"])

    refute constraints["collapsible"]
    assert constraints["disabled"]
    assert_equal "true", panel["data-disabled"]
  end

  test "ids must be one token" do
    [ "two words", "", 'a"b' ].each do |bad|
      assert_raises(ArgumentError) { PanelGroup.new(id: bad) }
      assert_raises(ArgumentError) { Panel.new(id: bad) }
      assert_raises(ArgumentError) { Handle.new(id: bad) }
    end
  end

  test "handle renders the keyboard and focus actions and appends a caller action" do
    handle = group(handle: { data: { action: "click->x#y" } }).at_css("[data-slot=resizable-handle]")

    assert_equal "keydown->chadcn--resizable#keydown focus->chadcn--resizable#focus blur->chadcn--resizable#blur click->x#y",
                 handle["data-action"]
  end

  test "the generated root helpers render the same HTML as the explicit classes" do
    explicit = render_view do
      render(PanelGroup.new(class: "h-8")) do
        render(Panel.new(default_size: "30%")) { plain "One" }
        render Handle.new(with_handle: true)
        render(Panel.new) { plain "Two" }
      end
    end
    helpers = render_view do
      render(Chadcn::Resizable.new) do |resizable|
        resizable.panel_group(class: "h-8") do
          resizable.panel(default_size: "30%") { plain "One" }
          resizable.handle(with_handle: true)
          resizable.panel { plain "Two" }
        end
      end
    end

    assert_equal explicit, helpers
  end
end

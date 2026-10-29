# frozen_string_literal: true

require_relative "chart_helper"

class Chadcn::Chart::Cartesian::WiringTest < Chadcn::TestCase
  include ChartHelper

  PREFIX = "data-chadcn--chart-"

  def chart_root(html) = parse(html).at_css("div[data-slot='chart']")

  def declare(chart, tooltip: {}, **axis)
    chart.x_axis(data_key: :month, **axis)
    chart.bar(data_key: :desktop)
    chart.tooltip(content: Chadcn::Chart::Tooltip::Content.new, **tooltip) if tooltip
  end

  def wiring_of(**props, &block)
    block ||= ->(chart) { declare(chart) }
    chart_root(render_chart(**props, &block))
  end

  def value(node, name) = node["#{PREFIX}#{name}-value"]

  def json(node, name) = JSON.parse(value(node, name))

  test "the chart is horizontal, steps +1, has the accessibility layer and ticks at the band centers" do
    node = wiring_of

    assert_equal "horizontal", value(node, "layout")
    assert_equal "1", value(node, "keyboard-step")
    assert_equal "true", value(node, "accessibility-layer")
    ticks = json(node, "ticks")

    assert_equal((0..5).to_a, ticks.map { |tick| tick["index"] })
    assert_in_delta 30.8333, ticks.first["coordinate"], 1e-4
    assert_equal({ "x" => 5, "y" => 5, "width" => 310, "height" => 160 }, json(node, "plot"))
  end

  test "the interaction starts untouched with recharts' defaults for the tooltip" do
    node = wiring_of

    %w[pointer-index keyboard-index].each { |name| assert_equal "-1", value(node, name) }
    %w[pointer-active keyboard-active].each { |name| assert_equal "false", value(node, name) }
    assert_equal "-1", value(node, "default-index")
    assert_equal "axis", value(node, "tooltip-event-type")
    assert_equal "hover", value(node, "trigger")
    assert_equal "", value(node, "tooltip-active")
    assert_equal({ "x" => 10, "y" => 10 }, json(node, "offset"))
    assert_equal({ "x" => false, "y" => false }, json(node, "allow-escape"))
    assert_equal({ "x" => false, "y" => false }, json(node, "reverse-direction"))
    assert_equal({}, json(node, "position"))
    assert_equal "transform 400ms ease", value(node, "transition")
    assert_equal "true", value(node, "transition-auto")
    assert_equal({}, json(node, "wrapper-style"))
  end

  test "every Tooltip option reaches its value" do
    node = wiring_of do |chart|
      declare(chart, tooltip: { default_index: "2", active: true, trigger: :click, offset: { x: 4 }, allow_escape_view_box: { x: true },
                                reverse_direction: { y: true }, position: { x: 12, y: nil }, is_animation_active: true, animation_duration: 150,
                                animation_easing: :linear, wrapper_style: { zIndex: 3, backgroundColor: "red" } })
    end

    assert_equal "2", value(node, "default-index")
    assert_equal "true", value(node, "tooltip-active")
    assert_equal "click", value(node, "trigger")
    assert_equal({ "x" => 4, "y" => 10 }, json(node, "offset"))
    assert_equal({ "x" => true, "y" => false }, json(node, "allow-escape"))
    assert_equal({ "x" => false, "y" => true }, json(node, "reverse-direction"))
    assert_equal({ "x" => 12 }, json(node, "position"))
    assert_equal "transform 150ms linear", value(node, "transition")
    assert_equal "false", value(node, "transition-auto")
    assert_equal({ "z-index" => "3", "background-color" => "red" }, json(node, "wrapper-style"))
  end

  test "a numeric offset applies to both axes, active false and a switched off animation are written as such" do
    node = wiring_of { |chart| declare(chart, tooltip: { offset: 20, active: false, is_animation_active: false }) }

    assert_equal({ "x" => 20, "y" => 20 }, json(node, "offset"))
    assert_equal "false", value(node, "tooltip-active")
    assert_equal "", value(node, "transition")
    assert_equal "false", value(node, "transition-auto")
  end

  test "the keyboard step is -1 for a reversed XAxis and always -1 for a vertical layout" do
    reversed = wiring_of { |chart| declare(chart, reversed: true) }
    vertical = wiring_of(layout: :vertical) do |chart|
      chart.x_axis(type: :number)
      chart.y_axis(data_key: :month, type: :category)
      chart.bar(data_key: :desktop)
      chart.tooltip(content: Chadcn::Chart::Tooltip::Content.new)
    end

    assert_equal "-1", value(reversed, "keyboard-step")
    assert_equal "-1", value(vertical, "keyboard-step")
    assert_equal "vertical", value(vertical, "layout")
    ys = json(vertical, "ticks").map { |tick| tick["coordinate"] }

    assert_equal ys.sort, ys, "ticks run along y in a vertical layout"
  end

  test "without a tooltip only the layout, the step and the accessibility layer are written" do
    node = wiring_of(accessibility_layer: false) { |chart| chart.bar(data_key: :desktop) }

    assert_equal "false", value(node, "accessibility-layer")
    assert_nil value(node, "ticks")
    assert_nil value(node, "trigger")
  end

  test "the actions are on .recharts-wrapper and the targets on the svg and the tooltip wrapper" do
    doc = parse(render_chart { |chart| declare(chart) })
    actions = doc.at_css(".recharts-wrapper")["data-action"].split

    assert_equal %w[pointermove->chadcn--chart#move pointerleave->chadcn--chart#leave click->chadcn--chart#click focusin->chadcn--chart#focus
                    focusout->chadcn--chart#blur keydown->chadcn--chart#key keydown@document->chadcn--chart#dismiss], actions
    assert_equal "surface", doc.at_css("svg.recharts-surface")["data-chadcn--chart-target"]
    assert_equal "tooltip", doc.at_css(".recharts-tooltip-wrapper")["data-chadcn--chart-target"]
    assert_nil doc.at_css("div[data-slot='chart']")["data-chadcn--chart-target"]
    assert_nil doc.at_css(".recharts-wrapper")["data-chadcn--chart-layout-value"], "values live on the controller element only"
  end

  test "the default index cursor and active dots are targets, so the controller can replace them" do
    doc = parse(render_chart(Chadcn::Chart::LineChart) do |chart|
      chart.x_axis(data_key: :month)
      chart.line(data_key: :desktop)
      chart.tooltip(default_index: 1, content: Chadcn::Chart::Tooltip::Content.new)
    end)

    assert_equal "cursor", doc.at_css("path.recharts-tooltip-cursor")["data-chadcn--chart-target"]
    assert_equal "activeDots", doc.at_css("g.recharts-active-dot")["data-chadcn--chart-target"]
  end

  test "each template carries the layer of its cursor and the payload the activate event hands out" do
    doc = parse(render_chart { |chart| declare(chart) })
    template = doc.css("template[data-chadcn--chart-target='tooltipTemplate']")[1]

    assert_equal 200, JSON.parse(template["data-cursor"])["layer"]
    payload = JSON.parse(template["data-payload"])

    assert_equal 1, payload.length
    assert_equal({ "name" => "desktop", "dataKey" => "desktop", "value" => 305 }, payload.first.slice("name", "dataKey", "value"))
    assert_not_includes payload.first.keys, "payload", "the data row stays out of the template"
  end

  test "a chart with no container still renders and is simply not wired" do
    doc = parse(render_bare_chart { |chart| declare(chart) })

    assert_nil doc.at_css("[data-controller]")
    assert_nil doc.at_css("template")
  end
end

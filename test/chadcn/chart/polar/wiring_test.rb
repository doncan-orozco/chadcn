# frozen_string_literal: true

require_relative "polar_helper"

class Chadcn::Chart::Polar::WiringTest < Chadcn::TestCase
  include PolarHelper

  CONTENT = Chadcn::Chart::Tooltip::Content.new(hide_label: true)
  TOOLTIP_VALUES = %w[
    accessibility-layer allow-escape default-index keyboard-active keyboard-index keyboard-step layout offset plot pointer-active pointer-index
    pointer-series polar position reverse-direction ticks tooltip-active tooltip-event-type trigger transition transition-auto wrapper-style
  ].freeze
  ACTION = Chadcn::Chart::Cartesian::Wiring::ACTION

  def controller(html) = parse(html).at_css("div[data-slot=chart]")

  def value(node, name) = node["data-chadcn--chart-#{name}-value"]

  def value_names(node) = node.attributes.keys.grep(/\Adata-chadcn--chart-.*-value\z/).map { |name| name[/\Adata-chadcn--chart-(.*)-value\z/, 1] }

  def radar_html(tooltip = { default_index: 1, content: CONTENT })
    render_radar do |chart|
      chart.polar_angle_axis(data_key: :month)
      chart.tooltip(**tooltip)
      chart.radar(data_key: :desktop, fill: "var(--color-desktop)")
    end
  end

  def ticks(node) = JSON.parse(value(node, "ticks")).map { |tick| [ tick["index"], tick["coordinate"] ] }

  test "a pie publishes an item tooltip with a tick per sector, the plot and every action, and tags its sectors as tooltip items" do
    html = render_pie(around: ->(chart) { chart.tooltip(default_index: 1, content: CONTENT) })
    node = controller(html)
    doc = parse(html)

    assert_equal "chadcn--chart", node["data-controller"]
    assert_equal "item", value(node, "tooltip-event-type")
    assert_equal "1", value(node, "default-index")
    assert_equal [ 0, 1, 2, 3, 4 ], ticks(node).map(&:first)
    assert_equal %w[x y width height].sort, JSON.parse(value(node, "plot")).keys.sort
    assert_equal ACTION, doc.at_css(".recharts-wrapper")["data-action"]
    groups = doc.css("g.recharts-pie-sector")

    assert_equal(%w[tooltipItem] * 5, groups.map { |group| group["data-chadcn--chart-target"] })
    assert_equal([ %w[0 0], %w[0 1], %w[0 2], %w[0 3], %w[0 4] ], groups.map { |group| [ group["data-chadcn--chart-series"], group["data-chadcn--chart-index"] ] })
  end

  test "a pie's templates are item templates: the series, and the sector's tooltip position as the item coordinate" do
    doc = parse(render_pie(around: ->(chart) { chart.tooltip(content: CONTENT) }))
    template = doc.at_css('template[data-index="1"]')

    assert_equal "0", template["data-series"]
    assert_equal JSON.parse(template["data-coordinate"]), JSON.parse(template["data-item-coordinate"])
    assert_nil template["data-pointer-cursor"]
  end

  def radial_html(tooltip = { default_index: 2, content: CONTENT })
    render_radial_bar do |chart|
      chart.tooltip(**tooltip)
      chart.radial_bar(data_key: :visitors)
    end
  end

  test "a radar publishes a centric axis tooltip: the angle of every category, its polar view box and every action" do
    html = radar_html
    node = controller(html)

    assert_equal "axis", value(node, "tooltip-event-type")
    assert_equal "1", value(node, "default-index")
    assert_equal "centric", value(node, "layout")
    assert_equal [ [ 0, 90 ], [ 1, 30 ], [ 2, -30 ], [ 3, -90 ], [ 4, -150 ], [ 5, -210 ] ], ticks(node)
    assert_equal({ "cx" => 160, "cy" => 100, "innerRadius" => 0, "outerRadius" => 76, "startAngle" => 90, "endAngle" => -270, "axis" => "angle",
                   "range" => [ 90, -270 ] }, JSON.parse(value(node, "polar")))
    assert_equal ACTION, parse(html).at_css(".recharts-wrapper")["data-action"]
  end

  test "a radial bar publishes a radial axis tooltip: the radius of every ring and its polar view box" do
    html = radial_html
    node = controller(html)

    assert_equal "axis", value(node, "tooltip-event-type")
    assert_equal "2", value(node, "default-index")
    assert_equal "radial", value(node, "layout")
    assert_equal [ [ 0, 41.6667 ], [ 1, 65 ], [ 2, 88.3333 ] ], ticks(node)
    assert_equal({ "cx" => 160, "cy" => 100, "innerRadius" => 30, "outerRadius" => 100, "startAngle" => 0, "endAngle" => 360, "axis" => "radius",
                   "range" => [ 30, 100 ] }, JSON.parse(value(node, "polar")))
    assert_equal ACTION, parse(html).at_css(".recharts-wrapper")["data-action"]
  end

  test "the keyboard of a polar chart always steps forward, and its accessibility layer is the chart's" do
    assert_equal %w[1 true], [ value(controller(radar_html), "keyboard-step"), value(controller(radar_html), "accessibility-layer") ]
    off = render_radar(chart: { accessibility_layer: false }) do |chart|
      chart.polar_angle_axis(data_key: :month)
      chart.tooltip(content: CONTENT)
      chart.radar(data_key: :desktop)
    end

    assert_equal "false", value(controller(off), "accessibility-layer")
  end

  test "a radar's template carries the line cursor the pointer draws, a radial bar's the ring; cursor: false draws none" do
    radar = parse(radar_html).at_css('template[data-index="1"]')
    cursor = JSON.parse(radar["data-pointer-cursor"])

    assert_equal [ "path", 1100 ], cursor.values_at("tag", "layer")
    assert_equal "recharts-curve recharts-tooltip-cursor", cursor.dig("attrs", "class")
    assert_equal "M160,100L225.818,62", cursor.dig("attrs", "d")
    assert_nil radar["data-cursor"]

    ring = JSON.parse(parse(radial_html).at_css('template[data-index="0"]')["data-pointer-cursor"])

    assert_equal "recharts-sector recharts-tooltip-cursor", ring.dig("attrs", "class")
    assert_equal %w[160 100], ring["attrs"].values_at("cx", "cy")
    assert ring.dig("attrs", "d").start_with?("M 201.6667,100")
    assert_nil parse(radar_html(default_index: 1, cursor: false, content: CONTENT)).at_css('template[data-index="1"]')["data-pointer-cursor"]
  end

  test "the interaction values start at the server state and the tooltip options are published as they are" do
    [ radar_html, radial_html, render_pie(around: ->(chart) { chart.tooltip(default_index: 1, content: CONTENT) }) ].each do |html|
      node = controller(html)

      names = %w[pointer-index pointer-active keyboard-index keyboard-active]

      assert_equal(%w[-1 false -1 false], names.map { |name| value(node, name) })
      assert_equal "hover", value(node, "trigger")
      assert_equal({ "x" => 10, "y" => 10 }, JSON.parse(value(node, "offset")))
      assert_equal "transform 400ms ease", value(node, "transition")
      assert_equal "true", value(node, "transition-auto")
      assert_equal "", value(node, "tooltip-active")
    end
  end

  test "a radar with shared: false stays an axis tooltip with its templates (RadarChart allows axis only)" do
    html = radar_html(default_index: 1, shared: false, content: CONTENT)
    node = controller(html)

    assert_equal "axis", value(node, "tooltip-event-type")
    assert_equal "1", value(node, "default-index")
    assert_equal 6, parse(html).css("template").size
  end

  test "a pie ignores shared: false: it is always an item tooltip with its sector templates" do
    html = render_pie(around: ->(chart) { chart.tooltip(default_index: 1, shared: false, content: CONTENT) })

    assert_equal "item", value(controller(html), "tooltip-event-type")
    assert_equal 5, parse(html).css("template").size
  end

  test "a polar chart publishes the tooltip values, its layout, its keyboard and its polar view box" do
    assert_equal TOOLTIP_VALUES.sort, value_names(controller(radar_html)).sort
  end

  test "a chart without a tooltip publishes no value at all" do
    html = render_radar { |chart| chart.radar(data_key: :desktop) }
    pie = render_pie
    radial = render_radial_bar { |chart| chart.radial_bar(data_key: :visitors) }

    [ html, pie, radial ].each do |rendered|
      assert_equal "chadcn--chart", controller(rendered)["data-controller"]
      assert_empty value_names(controller(rendered))
    end
  end

  test "active: false is published as the tooltip-active value" do
    node = controller(radar_html(active: false, default_index: 1, content: CONTENT))

    assert_equal "false", value(node, "tooltip-active")
  end

  test "the default active dot of a radar is the controller's activeDots target, once" do
    dots = parse(radar_html).css(".recharts-active-dot")

    assert_equal 1, dots.size
    assert_equal "activeDots", dots.first["data-chadcn--chart-target"]
  end

  test "the svg of a polar chart is the surface target, where the controller draws its dots" do
    assert_equal "surface", parse(radar_html).at_css("svg.recharts-surface")["data-chadcn--chart-target"]
  end

  test "a polar chart outside a container renders" do
    html = render_bare_chart(Chadcn::Chart::RadarChart) do |chart|
      chart.tooltip(default_index: 1)
      chart.radar(data_key: :desktop)
    end

    assert_includes html, "recharts-wrapper"
    refute_match(/data-chadcn--chart-[a-z-]+-value/, html)
    refute_includes html, "data-controller"
  end
end

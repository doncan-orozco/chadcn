# frozen_string_literal: true

require_relative "polar_helper"

class Chadcn::Chart::Polar::WiringTest < Chadcn::TestCase
  include PolarHelper

  CONTENT = Chadcn::Chart::Tooltip::Content.new(hide_label: true)
  TOOLTIP_VALUES = %w[
    allow-escape default-index keyboard-active keyboard-index offset plot pointer-active pointer-index position reverse-direction ticks
    tooltip-active tooltip-event-type trigger transition transition-auto wrapper-style
  ].freeze

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

  test "a pie publishes an item tooltip with the plot, no ticks and no action" do
    html = render_pie(around: ->(chart) { chart.tooltip(default_index: 1, content: CONTENT) })
    node = controller(html)

    assert_equal "chadcn--chart", node["data-controller"]
    assert_equal "item", value(node, "tooltip-event-type")
    assert_equal "1", value(node, "default-index")
    assert_equal "[]", value(node, "ticks")
    assert_equal %w[x y width height].sort, JSON.parse(value(node, "plot")).keys.sort
    assert_nil parse(html).at_css(".recharts-wrapper")["data-action"]
  end

  def radial_html(tooltip = { default_index: 2, content: CONTENT })
    render_radial_bar do |chart|
      chart.tooltip(**tooltip)
      chart.radial_bar(data_key: :visitors)
    end
  end

  test "a radar publishes an axis tooltip with its default index and no ticks" do
    html = radar_html
    node = controller(html)

    assert_equal "axis", value(node, "tooltip-event-type")
    assert_equal "1", value(node, "default-index")
    assert_equal "[]", value(node, "ticks")
    assert_nil parse(html).at_css(".recharts-wrapper")["data-action"]
  end

  test "a radial bar publishes an axis tooltip with its default index and no ticks" do
    html = radial_html
    node = controller(html)

    assert_equal "axis", value(node, "tooltip-event-type")
    assert_equal "2", value(node, "default-index")
    assert_equal "[]", value(node, "ticks")
    assert_nil parse(html).at_css(".recharts-wrapper")["data-action"]
  end

  test "the interaction values start at the server state and the tooltip options are published as they are" do
    [ radar_html, radial_html, render_pie(around: ->(chart) { chart.tooltip(default_index: 1, content: CONTENT) }) ].each do |html|
      node = controller(html)

      assert_equal %w[-1 false -1 false], %w[pointer-index pointer-active keyboard-index keyboard-active].map { |name| value(node, name) }
      assert_equal "hover", value(node, "trigger")
      assert_equal({ "x" => 10, "y" => 10 }, JSON.parse(value(node, "offset")))
      assert_equal "transform 400ms ease", value(node, "transition")
      assert_equal "true", value(node, "transition-auto")
      assert_equal "", value(node, "tooltip-active")
    end
  end

  test "a radial bar with shared: false is an item tooltip: inert controller, no template, an empty hidden wrapper" do
    html = radial_html(default_index: 2, shared: false, content: CONTENT)
    doc = parse(html)
    node = controller(html)

    assert_equal "item", value(node, "tooltip-event-type")
    assert_equal [], JSON.parse(value(node, "ticks"))
    assert_empty doc.css("template")
    assert_equal 0, doc.at_css(".recharts-tooltip-wrapper").children.size
    assert_includes doc.at_css(".recharts-tooltip-wrapper")["style"], "visibility: hidden"
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

  test "only the tooltip values are published, never the layout, the keyboard step or the accessibility layer" do
    names = value_names(controller(radar_html))

    assert_equal TOOLTIP_VALUES.sort, names.sort
    %w[layout keyboard-step accessibility-layer].each { |name| refute_includes names, name }
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

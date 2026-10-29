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

  test "a radar and a radial bar publish an axis tooltip with its default index and no ticks" do
    radial = render_radial_bar do |chart|
      chart.tooltip(default_index: 2, content: CONTENT)
      chart.radial_bar(data_key: :visitors)
    end

    { radar_html => "1", radial => "2" }.each do |html, index|
      node = controller(html)

      assert_equal "axis", value(node, "tooltip-event-type")
      assert_equal index, value(node, "default-index")
      assert_equal "[]", value(node, "ticks")
      assert_nil parse(html).at_css(".recharts-wrapper")["data-action"]
    end
  end

  test "only the tooltip values are published, never the layout, the keyboard step or the accessibility layer" do
    names = value_names(controller(radar_html))

    assert_equal TOOLTIP_VALUES.sort, names.sort
    %w[layout keyboard-step accessibility-layer].each { |name| refute_includes names, name }
  end

  test "a chart without a tooltip publishes no value at all" do
    html = render_radar { |chart| chart.radar(data_key: :desktop) }
    pie = render_pie

    [ html, pie ].each do |rendered|
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
  end
end

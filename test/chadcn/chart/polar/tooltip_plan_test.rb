# frozen_string_literal: true

require_relative "polar_helper"

class Chadcn::Chart::Polar::TooltipPlanTest < Chadcn::TestCase
  include PolarHelper

  def build(chart_class, series, rows: ROWS, **tooltip)
    declared = Chadcn::Chart::Polar::Declared.new(chart: chart_class)
    declared.declare(Chadcn::Chart::Tooltip.new(**tooltip))
    Array(series).each { |item| declared.declare(item) }
    type = chart_class::CHART_TYPE
    angles = type == :radar ? { start_angle: 90, end_angle: -270 } : { start_angle: 0, end_angle: 360 }
    settings = Chadcn::Chart::Polar::ChartSettings.new(
      type: type, layout: chart_class::LAYOUT, width: 320, height: 200, margin: { top: 5, right: 5, bottom: 5, left: 5 }, rows: rows,
      text: Chadcn::Chart::Cartesian::Text.new, cx: "50%", cy: "50%", inner_radius: 0, outer_radius: "80%", bar_category_gap: "10%", bar_gap: 4,
      bar_size: nil, max_bar_size: nil, **angles
    )
    layout = Chadcn::Chart::Polar::Layout.new(declared, settings)
    [ Chadcn::Chart::Polar::TooltipPlan.new(layout: layout, declared: declared, rows: rows), layout ]
  end

  test "a pie has an entry per sector, the sector alone, at its centroid, with no label and no cursor" do
    pie = Chadcn::Chart::Pie.new(data: BROWSERS, data_key: :visitors, name_key: :browser)
    plan, = build(Chadcn::Chart::PieChart, pie, rows: [])
    first = plan.entries.first

    assert_equal 5, plan.entries.size
    assert_equal [ 0, nil, nil, [] ], [ first.index, first.label, first.cursor, first.dots ]
    assert_equal [ "chrome", "visitors", 275, "var(--color-chrome)" ], first.payload.first.values_at(:name, :data_key, :value, :color)
    assert_equal 1, first.payload.size
    assert_in_delta 182.596, first.coordinate[:x], 0.001
    assert_in_delta 69.448, first.coordinate[:y], 0.001
  end

  test "a pie row's cell colors the entry and the row is the entry with what the cell gave" do
    pie = Chadcn::Chart::Pie.new(data: BROWSERS, data_key: :visitors, name_key: :browser)
    pie.declare(Chadcn::Chart::Cell.new(fill: "blue"))
    first = build(Chadcn::Chart::PieChart, pie, rows: []).first.entries.first

    assert_equal "blue", first.payload.first[:color]
    assert_equal %w[blue chrome], first.payload.first[:payload].values_at(:fill, :browser)
  end

  test "a hidden pie has no entries unless include_hidden, tooltip_type is kept for the content to drop, nil values are filtered" do
    hidden = Chadcn::Chart::Pie.new(data: BROWSERS, data_key: :visitors, hide: true)

    assert_empty build(Chadcn::Chart::PieChart, hidden, rows: []).first.entries
    assert_equal 5, build(Chadcn::Chart::PieChart, hidden, rows: [], include_hidden: true).first.entries.size
    silenced = Chadcn::Chart::Pie.new(data: BROWSERS, data_key: :visitors, tooltip_type: :none)

    assert_equal :none, build(Chadcn::Chart::PieChart, silenced, rows: []).first.entries.first.payload.first[:type]
  end

  test "a radar has an entry per category: the label is the category, the payload the radar at the row, the active dot on its point" do
    radar = Chadcn::Chart::Radar.new(data_key: :desktop, fill: "var(--color-desktop)")
    plan, = build(Chadcn::Chart::RadarChart, [ Chadcn::Chart::PolarAngleAxis.new(data_key: :month), radar ])
    march = plan.entries[2]

    assert_equal 6, plan.entries.size
    assert_equal [ 2, 2 ], [ march.index, plan.entries.index(march) ]
    assert_equal [ "desktop", 237, "var(--color-desktop)" ], march.payload.first.values_at(:name, :value, :color)
    assert_nil march.cursor
    assert_equal [ "4", "#fff", "2", "var(--color-desktop)" ], march.dots.first.attrs.values_at(:r, :stroke, :"stroke-width", :fill)
    assert_equal "208.7464", march.dots.first.attrs[:cx]
  end

  test "the anchor of an axis entry is recharts' own: the middle of the chart across, the tick coordinate along" do
    plan, = build(Chadcn::Chart::RadarChart, [ Chadcn::Chart::PolarAngleAxis.new(data_key: :month), Chadcn::Chart::Radar.new(data_key: :desktop) ])

    assert_equal [ 162.5, 90.0 ], plan.entries.first.coordinate.values_at(:x, :y)
  end

  test "a radar's active dot is switched off by active_dot: false or restyled with a Hash of shape attributes" do
    axis = Chadcn::Chart::PolarAngleAxis.new(data_key: :month)
    off, = build(Chadcn::Chart::RadarChart, [ axis, Chadcn::Chart::Radar.new(data_key: :desktop, active_dot: false) ])
    styled, = build(Chadcn::Chart::RadarChart, [ axis, Chadcn::Chart::Radar.new(data_key: :desktop, active_dot: { r: 6 }) ])

    assert_empty off.entries.first.dots
    assert_equal "6", styled.entries.first.dots.first.attrs[:r]
    assert_raises(ArgumentError) { build(Chadcn::Chart::RadarChart, [ Chadcn::Chart::Radar.new(data_key: :desktop, active_dot: { onclick: "x" }) ]) }
  end

  test "a radial bar has an entry per ring: the row as the arc has it (with the cell), the value of the row, the fill of the bar" do
    bar = Chadcn::Chart::RadialBar.new(data_key: :visitors, fill: "green")
    bar.declare(Chadcn::Chart::Cell.new(fill: "blue"))
    plan, = build(Chadcn::Chart::RadialBarChart, bar, rows: BROWSERS.first(3))
    first = plan.entries.first

    assert_equal 3, plan.entries.size
    assert_equal [ 0, 0 ], [ first.index, first.label ]
    assert_equal [ "visitors", 275, "green" ], first.payload.first.values_at(:name, :value, :color)
    assert_equal %w[blue chrome], first.payload.first[:payload].values_at(:fill, :browser)
    assert_empty first.dots
  end

  test "default_index picks the entry, active: false hides it, a string index works" do
    pie = Chadcn::Chart::Pie.new(data: BROWSERS, data_key: :visitors, name_key: :browser)

    assert_equal 1, build(Chadcn::Chart::PieChart, pie, rows: [], default_index: 1).first.default_entry.index
    assert_equal 2, build(Chadcn::Chart::PieChart, pie, rows: [], default_index: "2").first.default_entry.index
    assert_nil build(Chadcn::Chart::PieChart, pie, rows: [], default_index: 1, active: false).first.default_entry
    assert_nil build(Chadcn::Chart::PieChart, pie, rows: []).first.default_entry
  end

  test "a chart with no category axis (a radar over a number axis) has no entries" do
    axis = Chadcn::Chart::PolarAngleAxis.new(data_key: :desktop, type: :number, domain: [ 0, 400 ])
    plan, = build(Chadcn::Chart::RadarChart, [ axis, Chadcn::Chart::Radar.new(data_key: :desktop) ])

    assert_empty plan.entries
  end
end

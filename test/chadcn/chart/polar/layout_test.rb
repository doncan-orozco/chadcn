# frozen_string_literal: true

require_relative "polar_helper"

class Chadcn::Chart::Polar::LayoutTest < Chadcn::TestCase
  include PolarHelper

  def layout(type: :radar, layout: :centric, declare: [], width: 320, height: 200, margin: { top: 5, right: 5, bottom: 5, left: 5 }, **settings)
    chart = { radar: Chadcn::Chart::RadarChart, pie: Chadcn::Chart::PieChart, radial_bar: Chadcn::Chart::RadialBarChart }.fetch(type)
    declared = Chadcn::Chart::Polar::Declared.new(chart: chart)
    declare.each { |part| declared.declare(part) }
    text = Chadcn::Chart::Cartesian::Text.new
    options = { type: type, layout: layout, width: width, height: height, margin: margin, rows: ROWS, text: text, cx: "50%", cy: "50%", inner_radius: 0,
                outer_radius: "80%", start_angle: 90, end_angle: -270, bar_category_gap: "10%", bar_gap: 4, bar_size: nil, max_bar_size: nil }
    Chadcn::Chart::Polar::Layout.new(declared, Chadcn::Chart::Polar::ChartSettings.new(**options, **settings))
  end

  test "the plot is the chart less the margin, the view box the largest circle in it, 80% of it" do
    result = layout

    assert_equal({ x: 5.0, y: 5.0, width: 310.0, height: 190.0 }, result.plot)
    assert_equal [ 160.0, 100.0, 0.0, 76.0, 90, -270 ], result.view_box.to_h.values
    assert_equal({ top: 5.0, right: 5.0, bottom: 5.0, left: 5.0 }, result.margin)
  end

  test "the center is a share of the whole chart, the radii a share of the circle; numbers are pixels" do
    box = layout(cx: 100, cy: "25%", inner_radius: "10%", outer_radius: 50).view_box

    assert_equal [ 100.0, 50.0, 9.5, 50.0 ], [ box.cx, box.cy, box.inner_radius, box.outer_radius ]
  end

  test "a legend takes its room from the plot and from the radius, not from the center" do
    result = layout(declare: [ Chadcn::Chart::Legend.new ])

    assert_in_delta 162.0, result.plot[:height]
    assert_in_delta 100.0, result.view_box.cy
    assert_equal 162 / 2 * 0.8, result.view_box.outer_radius
    assert_equal 28, result.legend_box_height
  end

  test "a pie chart has no axes, the other two have one angle and one radius axis, implicit unless declared" do
    refute_predicate layout(type: :pie, layout: :centric), :axes?
    result = layout(declare: [ Chadcn::Chart::Radar.new(data_key: :desktop) ])

    assert_predicate result, :axes?
    assert_equal %i[angle radius], [ result.angle_axis.settings.kind, result.radius_axis.settings.kind ]
    assert_same result.angle_axis, result.tooltip_axis
    radial = layout(type: :radial_bar, layout: :radial, declare: [ Chadcn::Chart::RadialBar.new(data_key: :desktop) ])

    assert_same radial.radius_axis, radial.tooltip_axis
    assert_nil layout(type: :pie).tooltip_axis
  end

  test "a declared axis and the axes a series or a grid refers to are built, by id" do
    declared = [ Chadcn::Chart::PolarAngleAxis.new(angle_axis_id: "a", data_key: :month), Chadcn::Chart::Radar.new(data_key: :desktop, angle_axis_id: "a", radius_axis_id: "r"),
                 Chadcn::Chart::PolarGrid.new(radius_axis_id: "g") ]
    result = layout(declare: declared)

    assert_equal :month, result.angle_axis("a").settings.data_key
    assert_equal "r", result.radius_axis("r").settings.id
    assert_equal "g", result.radius_axis("g").settings.id
    assert_raises(KeyError) { result.angle_axis("nobody") }
  end

  test "series are placed in order; a hidden radar is not, a hidden pie still is" do
    radar = Chadcn::Chart::Radar.new(data_key: :desktop)
    hidden = Chadcn::Chart::Radar.new(data_key: :mobile, hide: true)
    pie = Chadcn::Chart::Pie.new(data_key: :desktop, hide: true)

    assert_equal [ radar ], layout(declare: [ radar, hidden ]).placed.map(&:series)
    assert_equal [ pie ], layout(type: :pie, declare: [ pie ]).placed.map(&:series)
  end

  test "a pie shows its own data, else the data of the chart" do
    own = Chadcn::Chart::Pie.new(data_key: :desktop, data: [ { desktop: 1 }, { desktop: 3 } ])
    shared = Chadcn::Chart::Pie.new(data_key: :desktop)

    assert_equal 2, layout(type: :pie, declare: [ own ]).placed.first.shapes.size
    assert_equal 6, layout(type: :pie, declare: [ shared ]).placed.first.shapes.size
  end

  test "a radial bar chart places every bar in its ring, and with no data places none but is still there" do
    bar = Chadcn::Chart::RadialBar.new(data_key: :desktop)
    result = layout(type: :radial_bar, layout: :radial, declare: [ bar ], start_angle: 0, end_angle: 360, inner_radius: 30, outer_radius: 100)
    empty = layout(type: :radial_bar, layout: :radial, declare: [ bar ], rows: [], start_angle: 0, end_angle: 360)

    assert_equal 6, result.placed.first.shapes.size
    assert_empty empty.placed.first.shapes
  end
end

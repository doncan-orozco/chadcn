# frozen_string_literal: true

require_relative "chart_helper"

class Chadcn::Chart::Cartesian::LayoutTest < Chadcn::TestCase
  include ChartHelper

  def layout(*parts, data: ROWS, margin: { top: 5, right: 5, bottom: 5, left: 5 }, direction: :horizontal, type: :bar, width: 320, height: 200, **chart)
    declared = Chadcn::Chart::Cartesian::Declared.new
    parts.each { |part| declared.declare(part) }
    settings = { type: type, direction: direction, width: width, height: height, margin: margin, rows: data, text: Chadcn::Chart::Cartesian::Text.new,
                 bar_category_gap: "10%", bar_gap: 4, bar_size: nil, max_bar_size: nil, stack_offset: :none, reverse_stack_order: false, base_value: nil }
    Chadcn::Chart::Cartesian::Layout.new(declared, Chadcn::Chart::Cartesian::ChartSettings.new(**settings, **chart))
  end

  test "the plot is the chart minus the margin and the room of the visible axes" do
    bare = layout(Chadcn::Chart::Bar.new(data_key: :desktop))
    axes = layout(Chadcn::Chart::XAxis.new, Chadcn::Chart::YAxis.new, Chadcn::Chart::Bar.new(data_key: :desktop))

    assert_equal({ x: 5.0, y: 5.0, width: 310.0, height: 190.0 }, bare.plot)
    assert_equal({ x: 65.0, y: 5.0, width: 250.0, height: 160.0 }, axes.plot)
    assert_equal({ top: 5.0, bottom: 35.0, left: 65.0, right: 5.0 }, axes.offset)
  end

  test "a margin side that is not given is 0, a hidden or mirrored axis takes no room" do
    mirrored = layout(Chadcn::Chart::XAxis.new(mirror: true), Chadcn::Chart::YAxis.new(hide: true), margin: { left: 12 })

    assert_equal({ x: 12.0, y: 0.0, width: 308.0, height: 200.0 }, mirrored.plot)
  end

  test "axes are placed at the edge of the plot they sit on, side by side when there are several" do
    chart = layout(Chadcn::Chart::XAxis.new(orientation: :top), Chadcn::Chart::YAxis.new(orientation: :right),
                   Chadcn::Chart::YAxis.new(y_axis_id: "b", width: 30, orientation: :right))
    top, right, second = chart.drawn_axes

    assert_equal [ 5.0, 5.0, 220.0, 30 ], [ top[:x], top[:y], top[:width], top[:height] ]
    assert_equal [ 225.0, 35.0 ], [ right[:x], right[:y] ]
    assert_equal [ 285.0, 30 ], [ second[:x], second[:width] ]
  end

  test "an axis nobody declared still exists, hidden and with a scale" do
    chart = layout(Chadcn::Chart::Bar.new(data_key: :desktop, y_axis_id: "other"))

    assert_predicate chart.axis(:y, "other"), :scaled?
    assert chart.axis(:x).settings.hide
    assert_empty chart.drawn_axes
  end

  test "a legend takes its room from the side it sits on" do
    bottom = layout(Chadcn::Chart::Legend.new, Chadcn::Chart::Bar.new(data_key: :desktop))
    top = layout(Chadcn::Chart::Legend.new(vertical_align: :top, height: 20), Chadcn::Chart::Bar.new(data_key: :desktop))
    side = layout(Chadcn::Chart::Legend.new(layout: :vertical, align: :right, width: 40), Chadcn::Chart::Bar.new(data_key: :desktop))

    assert_in_delta 162.0, bottom.plot[:height]
    assert_equal [ 25.0, 170.0 ], [ top.plot[:y], top.plot[:height] ]
    assert_in_delta 270.0, side.plot[:width]
  end

  test "grid points are the visible ticks plus the edges of the plot, or the points given" do
    chart = layout(Chadcn::Chart::XAxis.new(data_key: :month), Chadcn::Chart::Bar.new(data_key: :desktop))
    points = chart.grid_points(Chadcn::Chart::CartesianGrid.new)

    assert_equal [ 165.0, 125.0, 85.0, 45.0, 5.0 ], points[:horizontal]
    assert_equal 7, points[:vertical].size
    assert_equal [ 5.0, 315.0 ], points[:vertical].last(2)
    assert_equal [ 1, 2 ], chart.grid_points(Chadcn::Chart::CartesianGrid.new(horizontal_points: [ 1, 2 ]))[:horizontal]
    assert_in_delta 30.8333, chart.grid_points(Chadcn::Chart::CartesianGrid.new(sync_with_ticks: true))[:vertical].first, 0.0001
  end

  test "bars hidden or without a slot are not placed; every other series is, in order" do
    chart = layout(Chadcn::Chart::Bar.new(data_key: :desktop, hide: true), Chadcn::Chart::Bar.new(data_key: :mobile))

    assert_equal [ 1 ], chart.placed.map(&:index)
  end

  test "visible_ticks follow the axis tick setting" do
    chart = layout(Chadcn::Chart::XAxis.new(data_key: :month, tick: false), Chadcn::Chart::Bar.new(data_key: :desktop))

    assert_empty chart.visible_ticks(chart.axis(:x))
  end
end

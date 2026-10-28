# frozen_string_literal: true

require "chadcn/test_case"
require_relative "chart_helper"

class Chadcn::Chart::Cartesian::LinePointsTest < Chadcn::TestCase
  include ChartHelper

  # Lays a chart of `series` out and returns the placed series.
  def placed(chart_class_type, series, data: ROWS, layout: :horizontal, stack_offset: :none, base_value: nil, axes: [])
    declared = Chadcn::Chart::Cartesian::Declared.new
    axes.each { |axis| declared.declare(axis) }
    Array(series).each { |item| declared.declare(item) }
    chart = { type: chart_class_type, direction: layout, width: 320, height: 200, margin: { top: 5, right: 5, bottom: 5, left: 5 }, rows: data,
              text: Chadcn::Chart::Cartesian::Text.new, bar_category_gap: "10%", bar_gap: 4, bar_size: nil, max_bar_size: nil, stack_offset: stack_offset,
              reverse_stack_order: false, base_value: base_value }
    Chadcn::Chart::Cartesian::Layout.new(declared, chart).placed
  end

  test "a line has a point per row on a point scale" do
    points = placed(:line, Chadcn::Chart::Line.new(data_key: :desktop)).first.points

    assert_equal 6, points.size
    assert_equal [ 5.0, 315.0 ], [ points.first.x, points.last.x ]
    assert_equal 186, points.first.value
    assert_equal "January", points.first.row[:month]
    assert_equal [ points.first.x, points.first.y ], points.first.xy
  end

  test "a row without a value is a point that cannot be placed, kept in a horizontal layout" do
    rows = [ { desktop: 1 }, { desktop: nil }, { desktop: 3 } ]
    points = placed(:line, Chadcn::Chart::Line.new(data_key: :desktop), data: rows).first.points

    assert_equal 3, points.size
    assert_nil points[1].y
    assert_not_nil points[1].x
  end

  test "in a vertical layout the values run along x and the points that cannot be placed are dropped" do
    rows = [ { desktop: 1 }, { desktop: nil }, { desktop: 3 } ]
    axes = [ Chadcn::Chart::XAxis.new(type: :number), Chadcn::Chart::YAxis.new(type: :category) ]
    points = placed(:line, Chadcn::Chart::Line.new(data_key: :desktop), data: rows, layout: :vertical, axes: axes).first.points

    assert_equal 2, points.size
    assert_operator points.last.y, :>, points.first.y
  end

  test "an area closes on the baseline: the zero line, or the base value" do
    area = placed(:area, Chadcn::Chart::Area.new(data_key: :desktop)).first.area

    assert_kind_of Numeric, area.baseline
    refute area.range

    top = placed(:area, Chadcn::Chart::Area.new(data_key: :desktop, base_value: :data_max)).first.area.baseline

    assert_operator top, :<, area.baseline
    assert_equal top, placed(:area, Chadcn::Chart::Area.new(data_key: :desktop), base_value: "dataMax").first.area.baseline
    half = placed(:area, Chadcn::Chart::Area.new(data_key: :desktop, base_value: 160), data: [ { desktop: 0 }, { desktop: 320 } ])

    assert_in_delta 100.0, half.first.area.baseline
  end

  test "stacked areas have the lower edge of their stack as baseline" do
    first = Chadcn::Chart::Area.new(data_key: :mobile, stack_id: "a")
    second = Chadcn::Chart::Area.new(data_key: :desktop, stack_id: "a")
    lower, upper = placed(:area, [ first, second ]).map(&:area)

    assert_kind_of Array, upper.baseline
    assert_equal lower.points.map(&:y), upper.baseline.map(&:y)
  end

  test "a pair is a range with a lower edge of its own" do
    rows = ROWS.map { |row| row.merge(desktop: [ row[:desktop] - 30, row[:desktop] + 30 ]) }
    area = placed(:area, Chadcn::Chart::Area.new(data_key: :desktop), data: rows).first.area

    assert area.range
    assert_equal 6, area.baseline.size
    assert(area.baseline.zip(area.points).all? { |lower, top| lower.y > top.y })
  end
end

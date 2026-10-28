# frozen_string_literal: true

require "chadcn/test_case"
require_relative "chart_helper"

class Chadcn::Chart::Cartesian::BarShapesTest < Chadcn::TestCase
  include ChartHelper

  # Lays a bar chart out through the layout and returns the placed rectangles of the first series.
  def rects(data: ROWS, layout: :horizontal, **bar_options)
    axes = layout == :vertical ? [ Chadcn::Chart::XAxis.new(type: :number), Chadcn::Chart::YAxis.new(type: :category) ] : []
    series = Chadcn::Chart::Bar.new(data_key: :desktop, **bar_options)
    declared = Chadcn::Chart::Cartesian::Declared.new
    axes.each { |axis| declared.declare(axis) }
    declared.declare(series)
    chart = { type: :bar, direction: layout, width: 320, height: 200, margin: { top: 5, right: 5, bottom: 5, left: 5 }, rows: data,
              text: Chadcn::Chart::Cartesian::Text.new, bar_category_gap: "10%", bar_gap: 4, bar_size: nil, max_bar_size: nil, stack_offset: :none,
              reverse_stack_order: false, base_value: nil }
    Chadcn::Chart::Cartesian::Layout.new(declared, chart).placed.first.rects
  end

  test "a bar grows from the zero line to its value" do
    first = rects.first

    assert_equal([ 10.1667, 84.5625, 41.0, 110.4375 ], [ first.x, first.y, first.width, first.height ].map { |value| value.round(4) })
    assert_equal 186, first.value
    assert_equal 0, first.index
    assert_equal "January", first.row[:month]
  end

  test "a negative value gives a negative height from the zero line" do
    negative = rects(data: [ { desktop: 100 }, { desktop: -50 } ]).last

    positive = rects(data: [ { desktop: 100 }, { desktop: -50 } ]).first

    assert_operator negative.height, :<, 0
    assert_in_delta positive.y + positive.height, negative.y + negative.height, 0.0001
  end

  test "a row with no value, or a value of 0, draws no rectangle but keeps its index" do
    placed = rects(data: [ { desktop: 5 }, { desktop: nil }, { desktop: 0 }, { desktop: 7 } ])

    assert_equal [ 0, 3 ], placed.map(&:index)
  end

  test "min_point_size gives a tiny bar a visible length" do
    tiny = rects(data: [ { desktop: 100 }, { desktop: 0.5 } ], min_point_size: 5).last

    assert_in_delta 5.0, tiny.height, 0.0001
  end

  test "a vertical layout puts the categories on y and grows the bars along x" do
    placed = rects(layout: :vertical)

    assert_equal 6, placed.size
    assert_operator placed.first.width, :>, 0
    assert_operator placed[1].y, :>, placed[0].y
  end

  test "a stacked value is the pair of its stack, truncated to the domain" do
    placed = Chadcn::Chart::Cartesian::BarShapes.send(:truncate, [ -5.0, 400.0 ], [ 0.0, 320.0 ])

    assert_equal [ 0.0, 320.0 ], placed
    assert_equal [ 1.0, 2.0 ], Chadcn::Chart::Cartesian::BarShapes.send(:truncate, [ 1.0, 2.0 ], nil)
  end
end

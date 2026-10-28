# frozen_string_literal: true

require "chadcn/test_case"
require_relative "oracle_helper"

class Chadcn::Chart::Shape::AreaTest < Chadcn::TestCase
  include ChartOracle

  Area = Chadcn::Chart::Shape::Area

  test "path equals the recharts area for a baseline of points, a number and the vertical layout" do
    ChartOracle.shape.fetch("areas").each do |kase|
      baseline = kase.fetch("base") { kase.fetch("base_value") }
      path = Area.path(kase["points"], baseline: baseline, type: ChartOracle.snake(kase["type"]), layout: kase["layout"] || "horizontal")

      assert_equal kase["d"], path, "#{kase['type']} #{kase['layout']} #{baseline.class}"
    end
  end

  test "the top line runs forward and the baseline back" do
    assert_equal "M0,10L10,20L10,50L0,50Z", Area.path([ [ 0, 10 ], [ 10, 20 ] ], baseline: 50)
  end

  test "a vertical area closes on an x" do
    assert_equal "M10,0L20,10L5,10L5,0Z", Area.path([ [ 10, 0 ], [ 20, 10 ] ], baseline: 5, layout: :vertical)
  end

  test "an array baseline is paired by index" do
    path = Area.path([ [ 0, 10 ], [ 10, 20 ] ], baseline: [ [ 0, 30 ], [ 10, 40 ] ])

    assert_equal "M0,10L10,20L10,40L0,30Z", path
  end

  test "an undefined point ends the area, one run per segment" do
    points = [ [ 0, 1 ], [ 10, nil ], [ 20, 3 ], [ 30, 4 ] ]

    assert_equal "M0,1L0,9ZM20,3L30,4L30,9L20,9Z", Area.path(points, baseline: 9)
    assert_equal "M0,1L20,3L30,4L30,9L20,9L0,9Z", Area.path(points, baseline: 9, connect_nulls: true)
  end

  test "a missing baseline point makes the point undefined" do
    points = [ [ 0, 1 ], [ 10, 2 ], [ 20, 3 ] ]
    baseline = [ [ 0, 9 ], nil, [ 20, 9 ] ]

    assert_equal "M0,1L0,9ZM20,3L20,9Z", Area.path(points, baseline: baseline)
    assert_equal "M0,1L20,3L20,9L0,9Z", Area.path(points, baseline: baseline, connect_nulls: true)
  end

  test "no points, no path" do
    assert_nil Area.path([], baseline: 0)
    assert_nil Area.path([], baseline: [])
  end

  test "digits and defined are honored" do
    assert_equal "M0,0.3L0,1Z", Area.path([ [ 0, 1 / 3.0 ] ], baseline: 1, digits: 1)
    assert_equal "M0,2L0,9Z", Area.path([ [ 0, 2 ], [ 5, -1 ] ], baseline: 9, defined: ->(point) { point[1] >= 0 })
  end

  test "a baseline that is neither a number nor an array raises" do
    assert_raises(ArgumentError) { Area.path([ [ 0, 0 ] ], baseline: "0") }
    assert_raises(ArgumentError) { Area.path([ [ 0, 0 ] ], baseline: 0, layout: :sideways) }
  end
end

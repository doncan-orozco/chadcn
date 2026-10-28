# frozen_string_literal: true

require "chadcn/test_case"
require_relative "../shape/oracle_helper"

class Chadcn::Chart::Scale::PointTest < Chadcn::TestCase
  include ChartOracle

  Point = Chadcn::Chart::Scale::Point

  test "positions, step and bandwidth equal d3 scalePoint (only padding and align apply)" do
    ChartOracle.scale.fetch("point").each do |kase|
      options = ChartOracle.keywords(kase["opts"]).slice(:padding, :align)
      point = Point.new(count: kase["count"], range: kase["range"], **options)
      positions = Array.new(kase["count"]) { |index| point.call(index) }

      assert_all_close(kase["positions"], positions, "point #{kase.slice('count', 'range', 'opts')}")
      assert_close(kase["step"], point.step, "step #{kase.slice('count', 'range', 'opts')}")
      assert_equal 0, point.bandwidth
    end
  end

  test "outer padding keeps the first and last point away from the range ends" do
    point = Point.new(count: 3, range: [ 0, 100 ], padding: 0.5)

    assert_in_delta 100.0 / 6, point.call(0)
    assert_in_delta 500.0 / 6, point.call(2)
    assert_equal 3, point.count
    assert_equal [ 0.0, 100.0 ], point.range
  end

  test "an index outside the categories has no position" do
    assert_nil Point.new(count: 2, range: [ 0, 1 ]).call(2)
  end

  test "a single point sits at the align position of the range" do
    assert_in_delta 50.0, Point.new(count: 1, range: [ 0, 100 ]).call(0)
    assert_in_delta 0.0, Point.new(count: 1, range: [ 0, 100 ], align: 0).call(0)
  end
end

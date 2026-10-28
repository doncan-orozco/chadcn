# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Shape::Curve::Natural::ControlPointsTest < Chadcn::TestCase
  ControlPoints = Chadcn::Chart::Shape::Curve::Natural::ControlPoints

  test "points on a straight line get control points on that line, a third of a step apart" do
    first, second = ControlPoints.of([ 0.0, 3.0, 6.0, 9.0 ])

    assert_equal 3, first.size
    first.each_with_index { |value, index| assert_in_delta((index * 3.0) + 1.0, value, 1e-9) }
    second.each_with_index { |value, index| assert_in_delta((index * 3.0) + 2.0, value, 1e-9) }
  end

  test "three points give two segments that mirror each other" do
    first, second = ControlPoints.of([ 0.0, 1.0, 0.0 ])

    assert_equal [ 0.5, 1.0 ], first
    assert_equal [ 1.0, 0.5 ], second
  end
end

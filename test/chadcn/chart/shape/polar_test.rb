# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Shape::PolarTest < Chadcn::TestCase
  Polar = Chadcn::Chart::Shape::Polar

  test "polar_to_cartesian measures angles counterclockwise from 3 o'clock" do
    x, y = Polar.polar_to_cartesian(100, 100, 50, 90)

    assert_in_delta 100.0, x, 1e-9
    assert_in_delta 50.0, y, 1e-9
  end

  test "radians and degrees convert into each other" do
    assert_in_delta Math::PI, Polar.to_radians(180), 1e-12
    assert_in_delta 90.0, Polar.to_degrees(Math::PI / 2), 1e-12
  end

  test "delta_angle is the signed angle capped at the limit" do
    assert_in_delta 90.0, Polar.delta_angle(0, 90, limit: 360), 1e-12
    assert_in_delta(-90.0, Polar.delta_angle(90, 0, limit: 360), 1e-12)
    assert_in_delta 359.999, Polar.delta_angle(0, 720, limit: 359.999), 1e-12
    assert_in_delta(-360.0, Polar.delta_angle(0, -400, limit: 360), 1e-12)
    assert_equal 0, Polar.delta_angle(30, 30, limit: 360)
  end
end

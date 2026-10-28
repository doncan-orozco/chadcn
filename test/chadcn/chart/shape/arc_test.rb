# frozen_string_literal: true

require "chadcn/test_case"
require_relative "oracle_helper"

class Chadcn::Chart::Shape::ArcTest < Chadcn::TestCase
  include ChartOracle

  Arc = Chadcn::Chart::Shape::Arc

  test "sector_path equals the recharts Sector path character for character, whitespace included" do
    ChartOracle.cases(:shape, "sectors", minimum: 17).each do |kase|
      path = Arc.sector_path(**ChartOracle.keywords(kase["props"]))
      message = kase["props"].inspect
      kase["d"].nil? ? assert_nil(path, message) : assert_equal(kase["d"], path, message)
    end
  end

  test "a sector is nil when the outer radius is below the inner one or the angles are equal" do
    assert_nil Arc.sector_path(inner_radius: 50, outer_radius: 40, start_angle: 0, end_angle: 90)
    assert_nil Arc.sector_path(outer_radius: 40, start_angle: 45, end_angle: 45)
  end

  test "a full turn is clamped to 359.999 so the ends do not coincide" do
    path = Arc.sector_path(cx: 100, cy: 100, outer_radius: 50, start_angle: 0, end_angle: 360)

    assert_equal Arc.sector_path(cx: 100, cy: 100, outer_radius: 50, start_angle: 0, end_angle: 359.999), path
    assert_includes path, "A 50,50,0,"
  end

  test "defaults draw a sector at the origin" do
    assert_nil Arc.sector_path
    assert_includes Arc.sector_path(outer_radius: 10, end_angle: 90), "L 0,0 Z"
  end

  test "a percentage corner radius is a share of the ring width" do
    ring = { cx: 160, cy: 100, inner_radius: 40, outer_radius: 80, start_angle: 10, end_angle: 100 }

    assert_equal Arc.sector_path(**ring, corner_radius: 20), Arc.sector_path(**ring, corner_radius: "50%")
    assert_equal Arc.sector_path(**ring, corner_radius: 8), Arc.sector_path(**ring, corner_radius: "8")
  end

  test "a corner radius that is not a number draws the plain sector" do
    ring = { cx: 160, cy: 100, inner_radius: 40, outer_radius: 80, start_angle: 10, end_angle: 100 }
    plain = Arc.sector_path(**ring)

    assert_equal plain, Arc.sector_path(**ring, corner_radius: "wide")
    assert_equal plain, Arc.sector_path(**ring, corner_radius: nil)
    assert_equal plain, Arc.sector_path(**ring, corner_radius: -3)
  end

  test "corner_is_external changes the corners and force_corner_radius keeps them on short arcs" do
    ring = { cx: 160, cy: 100, inner_radius: 40, outer_radius: 80, start_angle: 10, end_angle: 12, corner_radius: 8 }

    assert_not_equal Arc.sector_path(**ring), Arc.sector_path(**ring, force_corner_radius: true)
    assert_includes Arc.sector_path(**ring, force_corner_radius: true), "a8,8,0,0,1,16,0"
  end
end

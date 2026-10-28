# frozen_string_literal: true

require "chadcn/test_case"
require_relative "oracle_helper"

class Chadcn::Chart::Shape::CurveTest < Chadcn::TestCase
  include ChartOracle

  Curve = Chadcn::Chart::Shape::Curve

  test "line equals the recharts path for every curve type and point set" do
    ChartOracle.cases(:shape, "curves", minimum: 74).each do |kase|
      layout = kase["layout"] || "horizontal"
      path = Curve.line(kase["points"], type: ChartOracle.snake(kase["type"]), layout: layout)

      message = "#{kase['type']} #{kase['set']} #{layout}"
      kase["d"].nil? ? assert_nil(path, message) : assert_equal(kase["d"], path, message)
    end
  end

  test "undefined points split the line into segments, connect_nulls draws through them" do
    ChartOracle.cases(:shape, "gaps", minimum: 2).each do |kase|
      path = Curve.line(kase["points"], type: :monotone, connect_nulls: kase["connect_nulls"])

      assert_equal kase["d"], path, "connect_nulls #{kase['connect_nulls']}"
    end
  end

  test "an empty line has no path" do
    assert_nil Curve.line([])
  end

  test "a lone point is a closed subpath, except for basis_open which draws nothing" do
    %i[linear linear_closed step_after monotone natural bump_x].each do |type|
      assert_equal "M5,5Z", Curve.line([ [ 5, 5 ] ], type: type), type.to_s
    end
    assert_nil Curve.line([ [ 5, 5 ] ], type: :basis_open)
  end

  test "nil, NaN and infinite coordinates are undefined points" do
    points = [ [ 0, 0 ], [ nil, 5 ], [ 10, Float::NAN ], [ Float::INFINITY, 1 ], [ 20, 20 ], [ 30, 30 ] ]

    assert_equal "M0,0ZM20,20L30,30", Curve.line(points)
    assert_equal "M0,0L20,20L30,30", Curve.line(points, connect_nulls: true)
  end

  test "a nil point is undefined too" do
    assert_equal "M0,0ZM10,10Z", Curve.line([ [ 0, 0 ], nil, [ 10, 10 ] ])
  end

  test "defined replaces the finite test" do
    points = [ [ 0, 0 ], [ 10, -1 ], [ 20, 20 ] ]

    assert_equal "M0,0ZM20,20Z", Curve.line(points, defined: ->(point) { point[1] >= 0 })
    assert_equal "M0,0L20,20", Curve.line(points, defined: ->(point) { point[1] >= 0 }, connect_nulls: true)
  end

  test "monotone and bump follow the layout" do
    points = [ [ 0, 0 ], [ 10, 30 ], [ 20, 10 ] ]

    assert_equal Curve.line(points, type: :monotone_x), Curve.line(points, type: :monotone)
    assert_equal Curve.line(points, type: :monotone_y), Curve.line(points, type: :monotone, layout: :vertical)
    assert_equal Curve.line(points, type: :bump_y), Curve.line(points, type: "bump", layout: "vertical")
    assert_not_equal Curve.line(points, type: :monotone), Curve.line(points, type: :monotone, layout: :vertical)
  end

  test "digits sets the rounding of the path numbers" do
    points = [ [ 0, 0 ], [ 1 / 3.0, 2 / 3.0 ] ]

    assert_equal "M0,0L0.333,0.667", Curve.line(points)
    assert_equal "M0,0L0.3,0.7", Curve.line(points, digits: 1)
  end

  test "build returns the interpolator of every type" do
    path = Chadcn::Chart::Shape::Path.new

    Curve::TYPES.each do |type|
      assert_kind_of Curve::Interpolator, Curve.build(type, path), type.to_s
    end
  end

  test "an unknown type or layout raises" do
    assert_raises(ArgumentError) { Curve.line([ [ 0, 0 ] ], type: :spline) }
    assert_raises(ArgumentError) { Curve.line([ [ 0, 0 ] ], layout: :diagonal) }
  end
end

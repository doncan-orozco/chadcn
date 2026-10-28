# frozen_string_literal: true

require "chadcn/test_case"
require_relative "oracle_helper"

class Chadcn::Chart::Shape::PieTest < Chadcn::TestCase
  include ChartOracle

  Pie = Chadcn::Chart::Shape::Pie

  test "pie equals the recharts computePieSectors angle layout" do
    ChartOracle.cases(:shape, "pies", minimum: 5).each do |kase|
      options = kase.slice("start_angle", "end_angle", "pad_angle", "min_angle").transform_keys(&:to_sym)
      sectors = Pie.layout(kase["values"], **options)

      assert_equal kase["sectors"].size, sectors.size, options.inspect
      kase["sectors"].zip(sectors).each do |expected, actual|
        expected.each { |key, value| assert_close(value, actual.fetch(key.to_sym), "#{options.inspect} #{key}") }
      end
    end
  end

  test "pie sizes sectors by value and gives a zero value no width" do
    sectors = Pie.layout([ 1, 0, 3 ])

    assert_in_delta 0.0, sectors[0][:start_angle], 1e-9
    assert_in_delta 90.0, sectors[0][:end_angle], 1e-9
    assert_in_delta 90.0, sectors[1][:end_angle], 1e-9
    assert_in_delta 360.0, sectors[2][:end_angle], 1e-9
    assert_in_delta 0.75, sectors[2][:percent], 1e-9
    assert_in_delta 225.0, sectors[2][:mid_angle], 1e-9
  end

  test "pie runs clockwise when the end angle is below the start" do
    sectors = Pie.layout([ 1, 1 ], start_angle: 90, end_angle: -270)

    assert_in_delta(-90.0, sectors[0][:end_angle], 1e-9)
    assert_in_delta(-270.0, sectors[1][:end_angle], 1e-9)
  end

  test "pie treats nil and NaN as zero and has nothing to lay out without a positive total" do
    assert_in_delta 1.0, Pie.layout([ nil, 5, Float::NAN ])[1][:percent], 1e-9
    assert_empty Pie.layout([])
    assert_empty Pie.layout([ 0, 0 ])
    assert_empty Pie.layout([ nil ])
  end

  test "pie ignores the pad angle for a single value" do
    assert_in_delta 360.0, Pie.layout([ 4 ], pad_angle: 10).first[:end_angle], 1e-9
  end
end

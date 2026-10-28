# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::ReferenceLineTest < Chadcn::TestCase
  test "defaults equal recharts'" do
    options = Chadcn::Chart::ReferenceLine.new(y: 1).options

    assert_equal [ "#ccc", 1, "none", 1, :discard, 0, 0 ], options.values_at(:stroke, :stroke_width, :fill, :fill_opacity, :if_overflow, :x_axis_id, :y_axis_id)
  end

  test "if_overflow accepts strings and the four recharts values" do
    assert_equal :extend_domain, Chadcn::Chart::ReferenceLine.new(y: 1, if_overflow: "extend_domain").options[:if_overflow]
    assert_equal %i[discard hidden visible extend_domain], Chadcn::Chart::ReferenceLine::OVERFLOWS
  end

  test "needs x or y and a known overflow" do
    assert_raises(ArgumentError) { Chadcn::Chart::ReferenceLine.new }
    assert_raises(ArgumentError) { Chadcn::Chart::ReferenceLine.new(x: 1, if_overflow: :drift) }
  end
end

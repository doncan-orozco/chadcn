# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::LineTest < Chadcn::TestCase
  test "defaults equal recharts'" do
    options = Chadcn::Chart::Line.new(data_key: :a).options

    assert_equal [ :linear, "#3182bd", 1, "#fff", true, true, false, :line ],
                 options.values_at(:type, :stroke, :stroke_width, :fill, :dot, :active_dot, :connect_nulls, :legend_type)
  end

  test "type accepts strings and every curve of the shapes" do
    assert_equal :monotone, Chadcn::Chart::Line.new(data_key: :a, type: "monotone").options[:type]
    assert_equal :step_before, Chadcn::Chart::Line.new(data_key: :a, type: :step_before).options[:type]
    assert_raises(ArgumentError) { Chadcn::Chart::Line.new(data_key: :a, type: :wavy) }
  end

  test "is a series of kind line that registers with its chart" do
    line = Chadcn::Chart::Line.new(data_key: :a)

    assert_equal :line, line.kind
    assert_kind_of Chadcn::Chart::Declaration, line
  end
end

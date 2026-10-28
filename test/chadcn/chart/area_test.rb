# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::AreaTest < Chadcn::TestCase
  test "defaults equal recharts'" do
    options = Chadcn::Chart::Area.new(data_key: :a).options

    assert_equal [ :linear, "#3182bd", 0.6, "#3182bd", 1, false, true ],
                 options.values_at(:type, :fill, :fill_opacity, :stroke, :stroke_width, :dot, :active_dot)
    assert_nil options[:stack_id]
    assert_nil options[:base_value]
  end

  test "invalid options raise" do
    assert_raises(ArgumentError) { Chadcn::Chart::Area.new(data_key: :a, type: :wavy) }
    assert_raises(ArgumentError) { Chadcn::Chart::Area.new(data_key: :a, legend_type: :banana) }
    assert_raises(ArgumentError) { Chadcn::Chart::Area.new(data_key: :a, tooltip_type: :loud) }
  end

  test "is a series of kind area" do
    assert_equal :area, Chadcn::Chart::Area.new(data_key: :a).kind
  end
end

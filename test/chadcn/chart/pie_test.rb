# frozen_string_literal: true

require_relative "polar/polar_helper"

class Chadcn::Chart::PieTest < Chadcn::TestCase
  include PolarHelper

  test "defaults equal recharts' (polar/Pie.js:542)" do
    options = Chadcn::Chart::Pie.new.options

    assert_equal [ :value, :name, "50%", "50%", 0, "80%" ], options.values_at(:data_key, :name_key, :cx, :cy, :inner_radius, :outer_radius)
    assert_equal [ 0, 360, 0, 0 ], options.values_at(:start_angle, :end_angle, :padding_angle, :min_angle)
    assert_equal [ "#808080", "#fff", true, 0, :rect, false ], options.values_at(:fill, :stroke, :label_line, :root_tab_index, :legend_type, :hide)
    assert_predicate options, :frozen?
  end

  test "strings and symbols are the same: legend_type, tooltip_type, data keys" do
    assert_equal :circle, Chadcn::Chart::Pie.new(legend_type: "circle").options[:legend_type]
    assert_equal :none, Chadcn::Chart::Pie.new(tooltip_type: "none").options[:tooltip_type]
    assert_equal "visitors", Chadcn::Chart::Pie.new(data_key: "visitors").options[:data_key]
  end

  test "refuses a bad legend or tooltip type, data, angle and an active shape" do
    assert_raises(ArgumentError) { Chadcn::Chart::Pie.new(legend_type: :triangle2) }
    assert_raises(ArgumentError) { Chadcn::Chart::Pie.new(tooltip_type: :hidden) }
    assert_raises(ArgumentError) { Chadcn::Chart::Pie.new(data: [ 1, 2 ]) }
    assert_raises(ArgumentError) { Chadcn::Chart::Pie.new(padding_angle: nil) }
    assert_raises(ArgumentError) { Chadcn::Chart::Pie.new(active_shape: true) }
    Chadcn::Chart::Pie.new(active_shape: false, is_animation_active: false)
  end

  test "the generated helper builds a pie and the block receives it" do
    yielded = nil
    render_pie { |pie| yielded = pie }

    assert_instance_of Chadcn::Chart::Pie, yielded
    assert_respond_to yielded, :cell
    assert_respond_to yielded, :label_list
  end
end

# frozen_string_literal: true

require_relative "polar/polar_helper"

class Chadcn::Chart::RadarTest < Chadcn::TestCase
  include PolarHelper

  test "defaults equal recharts' (polar/Radar.js:370)" do
    options = Chadcn::Chart::Radar.new(data_key: :a).options

    assert_equal [ false, true, false, :rect, 0, 0 ], options.values_at(:dot, :active_dot, :label, :legend_type, :angle_axis_id, :radius_axis_id)
    assert_nil options[:fill]
    assert_predicate options, :frozen?
  end

  test "the legend color is the stroke unless it is none, else the fill" do
    assert_equal "red", Chadcn::Chart::Radar.new(data_key: :a, stroke: "red", fill: "blue").legend_color
    assert_equal "blue", Chadcn::Chart::Radar.new(data_key: :a, stroke: "none", fill: "blue").legend_color
    assert_equal "blue", Chadcn::Chart::Radar.new(data_key: :a, fill: "blue").legend_color
    assert_nil Chadcn::Chart::Radar.new(data_key: :a).legend_color
  end

  test "strings and symbols are the same, a data key is required, bad types raise" do
    assert_equal :circle, Chadcn::Chart::Radar.new(data_key: :a, legend_type: "circle").options[:legend_type]
    assert_raises(ArgumentError) { Chadcn::Chart::Radar.new }
    assert_raises(ArgumentError) { Chadcn::Chart::Radar.new(data_key: :a, legend_type: :round) }
    assert_raises(ArgumentError) { Chadcn::Chart::Radar.new(data_key: :a, tooltip_type: :hidden) }
  end

  test "class lands on the group and the polygon, the other attributes on the polygon and the dots, id names the polygon" do
    html = render_radar do |chart|
      chart.polar_angle_axis(data_key: :month)
      chart.radar(data_key: :desktop, dot: true, class: "mine", id: "r1", stroke: "red", stroke_width: 2, name: "Desktop", stroke_dasharray: "2 2")
    end
    doc = parse(html)
    polygon = layer(doc, 100).at_css("path")
    dot = layer(doc, 600).at_css("circle")

    assert_equal %w[recharts-layer recharts-radar mine], layer(doc, 100).at_css("> g")["class"].split
    assert_equal [ "recharts-polygon mine", "r1", "red", "2", "2 2", "Desktop" ],
                 values(polygon, "class", "id", "stroke", "stroke-width", "stroke-dasharray", "name")
    assert_equal [ "recharts-dot recharts-radar-dot", "red", "2 2", "3" ], values(dot, "class", "stroke", "stroke-dasharray", "r")
    assert_nil dot["id"]
  end
end

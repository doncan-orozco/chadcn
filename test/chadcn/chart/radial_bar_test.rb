# frozen_string_literal: true

require_relative "polar/polar_helper"

class Chadcn::Chart::RadialBarTest < Chadcn::TestCase
  include PolarHelper

  test "defaults equal recharts' (polar/RadialBar.js:328)" do
    options = Chadcn::Chart::RadialBar.new(data_key: :a).options

    assert_equal [ false, 0, false, false, 0 ], options.values_at(:background, :corner_radius, :corner_is_external, :force_corner_radius, :min_point_size)
    assert_equal [ false, :rect ], options.values_at(:label, :legend_type)
    assert_predicate options, :frozen?
    assert_nil Chadcn::Chart::RadialBar.new(data_key: :a).legend_color
    assert_equal "red", Chadcn::Chart::RadialBar.new(data_key: :a, fill: "red").legend_color
  end

  test "bad types raise and a data key is required" do
    assert_raises(ArgumentError) { Chadcn::Chart::RadialBar.new }
    assert_raises(ArgumentError) { Chadcn::Chart::RadialBar.new(data_key: :a, legend_type: :round) }
    assert_raises(ArgumentError) { Chadcn::Chart::RadialBar.new(data_key: :a, tooltip_type: :x) }
    assert_equal :none, Chadcn::Chart::RadialBar.new(data_key: :a, tooltip_type: "none").options[:tooltip_type]
  end

  test "the bar's props land on every arc, the row and the cell win, the group takes only the class" do
    html = render_radial_bar do |chart|
      chart.radial_bar(data_key: :visitors, fill: "green", stroke: "black", stroke_width: 3, class: "grp", opacity: 0.5)
    end
    doc = parse(html)
    arc = arcs(doc).first

    assert_equal "recharts-layer recharts-area grp", layer(doc, 300).at_css("> g")["class"]
    assert_equal [ "var(--color-chrome)", "black", "3", "0.5" ], values(arc, "fill", "stroke", "stroke-width", "opacity")
  end
end

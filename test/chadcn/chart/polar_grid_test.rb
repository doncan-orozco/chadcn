# frozen_string_literal: true

require_relative "polar/polar_helper"

class Chadcn::Chart::PolarGridTest < Chadcn::TestCase
  include PolarHelper

  def grid(**props)
    html = render_radar do |chart|
      chart.polar_angle_axis(data_key: :month)
      chart.polar_grid(**props)
      chart.radar(data_key: :desktop)
    end
    layer(parse(html), -100).at_css("> g.recharts-polar-grid")
  end

  test "defaults equal recharts' (polar/PolarGrid.js:139)" do
    options = Chadcn::Chart::PolarGrid.new.options

    assert_equal [ :polygon, "#ccc", nil, true, 0, 0 ], options.values_at(:grid_type, :stroke, :fill, :radial_lines, :angle_axis_id, :radius_axis_id)
    assert_predicate options, :frozen?
  end

  test "circles for grid_type circle, a circle per ring with the radius written twice (radius, r)" do
    circles = grid(grid_type: "circle").css("circle")

    assert_equal 5, circles.size
    assert_equal %w[recharts-polar-grid-concentric-circle 19 19 160 100], values(circles[1], "class", "radius", "r", "cx", "cy")
  end

  test "radial_lines false draws the rings only; polar_angles and polar_radius replace the ticks" do
    plain = grid(radial_lines: false)
    custom = grid(polar_angles: [ 0, 90, 180 ], polar_radius: [ 20, 40 ])

    assert_nil plain.at_css("g.recharts-polar-grid-angle")
    assert_equal 5, plain.css("> g.recharts-polar-grid-concentric > path").size
    assert_equal(%w[20 40], custom.css("path").map { |ring| ring["radius"] })
    assert_equal 3, custom.css("line").size
    assert_equal %w[236 100], values(custom.css("line").first, "x2", "y2")
  end

  test "a fill draws a background shape behind the rings, filled, at the largest radius; none draws none" do
    filled = grid(fill: "#eee")
    none = grid(fill: "none")

    assert_equal 6, filled.css("> g.recharts-polar-grid-concentric > path").size
    assert_equal [ "#eee", "76" ], values(filled.at_css("> g.recharts-polar-grid-concentric > path"), "fill", "radius")
    assert_equal 5, none.css("> g.recharts-polar-grid-concentric > path").size
    assert(none.css("path").all? { |ring| ring["fill"] == "none" })
  end

  test "class and attributes land on every ring and every line, not on the group" do
    group = grid(class: "mine", stroke: "red", stroke_dasharray: "3 3", "data-x": "1")

    assert_equal "recharts-polar-grid", group["class"]
    assert_equal [ "red", "3 3", "1", "recharts-polar-grid-concentric-polygon mine" ],
                 values(group.at_css("path"), "stroke", "stroke-dasharray", "data-x", "class")
    assert_equal [ "red", "3 3", "1", "mine" ], values(group.at_css("line"), "stroke", "stroke-dasharray", "data-x", "class")
  end

  test "a grid in a pie chart, or one with no data to follow, draws nothing" do
    html = render_chart(Chadcn::Chart::PieChart, data: [], &:polar_grid)
    empty = render_radar(chart: { data: [] }, &:polar_grid)

    assert_empty layer(parse(html), -100).children
    assert_empty layer(parse(empty), -100).children
  end

  test "refuses a bad grid type and lists that are not numbers" do
    assert_raises(ArgumentError) { Chadcn::Chart::PolarGrid.new(grid_type: :square) }
    assert_raises(ArgumentError) { Chadcn::Chart::PolarGrid.new(polar_angles: "0") }
    assert_raises(ArgumentError) { Chadcn::Chart::PolarGrid.new(polar_radius: [ "a" ]) }
  end
end

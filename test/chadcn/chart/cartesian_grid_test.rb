# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::CartesianGridTest < Chadcn::TestCase
  include ChartHelper

  test "defaults equal recharts'" do
    options = Chadcn::Chart::CartesianGrid.new.options

    assert_equal [ true, true, "#ccc", "none", false, 0, 0 ],
                 options.values_at(:horizontal, :vertical, :stroke, :fill, :sync_with_ticks, :x_axis_id, :y_axis_id)
    assert_empty options[:horizontal_points]
  end

  test "vertical false draws only horizontal lines, horizontal false only vertical ones" do
    both = parse(render_chart do |chart|
      chart.cartesian_grid
      chart.bar(data_key: :desktop)
    end)
    horizontal = parse(render_chart do |chart|
      chart.cartesian_grid(vertical: false)
      chart.bar(data_key: :desktop)
    end)
    vertical = parse(render_chart do |chart|
      chart.cartesian_grid(horizontal: false)
      chart.bar(data_key: :desktop)
    end)

    assert layer(both, -100).at_css(".recharts-cartesian-grid-horizontal")
    assert layer(both, -100).at_css(".recharts-cartesian-grid-vertical")
    assert_nil layer(horizontal, -100).at_css(".recharts-cartesian-grid-vertical")
    assert_nil layer(vertical, -100).at_css(".recharts-cartesian-grid-horizontal")
  end

  test "a line carries the plot box, the stroke and the caller's attributes" do
    line = layer(parse(render_chart do |chart|
      chart.cartesian_grid(stroke: "red", class: "g")
      chart.bar(data_key: :desktop)
    end), -100).at_css("line")

    assert_equal %w[red none g 5 5 310 190], values(line, "stroke", "fill", "class", "x", "y", "width", "height")
  end

  test "explicit points replace the ticks" do
    lines = layer(parse(render_chart do |chart|
      chart.cartesian_grid(horizontal_points: [ 20, 40 ], vertical: false)
      chart.bar(data_key: :desktop)
    end), -100).css("line")

    assert_equal(%w[20 40], lines.map { |line| line["y1"] })
  end
end

# frozen_string_literal: true

require_relative "polar/polar_helper"

class Chadcn::Chart::PolarAngleAxisTest < Chadcn::TestCase
  include PolarHelper

  def axis(**props)
    html = render_radar do |chart|
      chart.polar_angle_axis(data_key: :month, **props)
      chart.radar(data_key: :desktop)
    end
    layer(parse(html), 500).at_css("> g.recharts-polar-angle-axis")
  end

  test "defaults equal recharts' (polar/defaultPolarAngleAxisProps.js)" do
    settings = Chadcn::Chart::PolarAngleAxis.new.settings

    assert_equal %i[auto outer polygon], [ settings.type, settings.orientation, settings.axis_line_type ]
    assert_equal [ 8, false ], [ settings.tick_size, settings.allow_decimals ]
    assert_equal [ true, true, true, 0, nil ], [ settings.tick, settings.tick_line, settings.axis_line, settings.id, settings.stroke ]
  end

  test "a circle axis line, an inner orientation (ticks inwards, labels flipped), a bigger tick" do
    circle = axis(axis_line_type: :circle, orientation: :inner, tick_size: 12)
    line = circle.at_css("> circle")
    first = circle.at_css("g.recharts-polar-angle-axis-tick")

    assert_equal [ "recharts-dot recharts-polar-angle-axis-line", "76", "none" ], values(line, "class", "r", "fill")
    assert_equal %w[160 24 160 36], values(first.at_css("line"), "x1", "y1", "x2", "y2")
    assert_equal "end", circle.css("text")[1]["text-anchor"]
  end

  test "tick, tick_line and axis_line can be switched off or styled with a Hash" do
    bare = axis(tick: false, tick_line: false, axis_line: false)
    styled = axis(tick: { fill: "blue", class: "tk" }, tick_line: { stroke: "green" }, axis_line: { stroke: "red" }, stroke: "gray")

    assert_nil bare.at_css("> path")
    assert_empty bare.css("line, text")
    assert_equal "red", styled.at_css("> path")["stroke"]
    assert_equal "green", styled.at_css("line")["stroke"]
    group = styled.at_css("g.recharts-polar-angle-axis-tick")

    assert_equal [ "blue", "recharts-layer recharts-polar-angle-axis-tick tk" ], [ group.at_css("text")["fill"], group["class"] ]
  end

  test "stroke colors the labels and the class replaces the class of the axis line and the tick lines" do
    group = axis(stroke: "gray", class: "mine")

    assert_equal "recharts-layer recharts-polar-angle-axis angleAxis mine", group["class"]
    assert_equal "gray", group.at_css("text")["fill"]
    assert_equal "recharts-polygon mine", group.at_css("> path")["class"]
    assert_equal "mine", group.at_css("line")["class"]
  end

  test "the labels go through the formatter" do
    labels = axis(tick_formatter: { slice: [ 0, 3 ] }).css("text").map(&:text)

    assert_equal %w[Jan Feb Mar Apr May Jun], labels
  end

  test "a reversed axis turns the categories the other way" do
    labels = axis(reversed: true).css("text")

    assert_equal "January", labels.first.text
    assert_equal(%w[start middle end end middle start], labels.map { |label| label["text-anchor"] })
    assert_equal %w[232.74613391789282 57.999999999999964], values(labels.first, "x", "y")
  end

  test "an axis in a pie chart is refused; bad values raise" do
    assert_raises(ArgumentError) { render_chart(Chadcn::Chart::PieChart, data: [], &:polar_angle_axis) }
    assert_raises(ArgumentError) { Chadcn::Chart::PolarAngleAxis.new(type: :log) }
    assert_raises(ArgumentError) { Chadcn::Chart::PolarAngleAxis.new(orientation: :left) }
    assert_raises(ArgumentError) { Chadcn::Chart::PolarAngleAxis.new(axis_line_type: :square) }
    assert_raises(ArgumentError) { Chadcn::Chart::PolarAngleAxis.new(domain: [ 1 ]) }
  end
end

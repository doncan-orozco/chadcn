# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::LineChartTest < Chadcn::TestCase
  include ChartHelper

  MARGIN = { left: 12, right: 12 }.freeze

  def monotone(**line)
    render_chart(Chadcn::Chart::LineChart, margin: MARGIN) do |chart|
      chart.cartesian_grid(vertical: false)
      chart.y_axis(tick_line: false, axis_line: false, tick_margin: 8)
      chart.x_axis(data_key: :month, tick_line: false, axis_line: false, tick_margin: 8, tick_formatter: SLICE)
      chart.line(data_key: :desktop, type: :monotone, stroke: "var(--color-desktop)", stroke_width: 2, **line)
    end
  end

  test "draws the monotone curve and one dot per point on a point scale, like recharts" do
    doc = parse(monotone)
    curve = layer(doc, 400).at_css("path.recharts-line-curve")
    dots = layer(doc, 600).css("circle.recharts-line-dot")

    assert curve["d"].start_with?("M72,71.187C87.733,39.578,103.467,7.969,119.2,7.969C134.933,7.969,150.667,23.552,166.4,44.094C182.133,64.635,197.867,131.219,213.6,131.219")
    assert_equal %w[none 170 236], [ curve["fill"], curve["height"], curve["width"] ]
    assert_equal([ 72, 119.2, 166.4, 213.6, 260.8, 308 ], dots.map { |dot| dot["cx"].to_f.round(4) })
    assert_equal [ "3", "var(--color-desktop)", "2" ], [ dots.first["r"], dots.first["stroke"], dots.first["stroke-width"] ]
    assert_equal "#fff", dots.first["fill"]
  end

  test "the plot starts after the margin and the y axis, and the last x label is pulled inside the chart" do
    doc = parse(monotone)
    clip = doc.at_css("clipPath rect")
    y_labels = layer(doc, 2000).css(".recharts-yAxis-tick-labels text")

    assert_equal %w[72 0 170 236], [ clip["x"], clip["y"], clip["height"], clip["width"] ]
    assert_equal %w[0 80 160 240 320], y_labels.map(&:text)
    assert_equal %w[end 58], [ y_labels.first["text-anchor"], y_labels.first["x"] ]
    assert_equal "8", y_labels.last["y"]
  end

  test "dot false draws no dots; a Hash styles them" do
    assert_empty layer(parse(monotone(dot: false)), 600).css("circle")

    styled = layer(parse(monotone(dot: { r: 5, fill: "blue", class: "pt" })), 600).css("circle").first

    assert_equal %w[5 blue], [ styled["r"], styled["fill"] ]
    assert_equal "recharts-dot recharts-line-dot pt", styled["class"]
  end

  test "a row without a value breaks the line unless connect_nulls is set" do
    rows = ROWS.each_with_index.map { |row, index| index == 2 ? row.except(:desktop) : row }
    broken = parse(render_chart(Chadcn::Chart::LineChart, data: rows) { |chart| chart.line(data_key: :desktop, dot: false) })
    joined = parse(render_chart(Chadcn::Chart::LineChart, data: rows) { |chart| chart.line(data_key: :desktop, dot: false, connect_nulls: true) })

    assert_equal 2, layer(broken, 400).at_css("path")["d"].scan("M").size
    assert_equal 1, layer(joined, 400).at_css("path")["d"].scan("M").size
  end

  test "a lone point is drawn as a dot" do
    doc = parse(render_chart(Chadcn::Chart::LineChart, data: [ { month: "A", desktop: 5 } ]) { |chart| chart.line(data_key: :desktop, dot: false) })

    assert_nil layer(doc, 400).at_css("path")
    assert_equal 1, layer(doc, 600).css("circle").size
  end

  test "stroke_dasharray, name and a custom class go on the curve and the group" do
    doc = parse(render_chart(Chadcn::Chart::LineChart) { |chart| chart.line(data_key: :desktop, stroke_dasharray: "3 3", name: "Desk", class: "mine") })
    group = layer(doc, 400).at_css("g.recharts-line")

    assert_includes group["class"], "mine"
    assert_equal [ "3 3", "Desk", "#3182bd", "1" ], values(group.at_css("path"), "stroke-dasharray", "name", "stroke", "stroke-width")
  end

  test "curve types other than linear shape the path; an unknown one raises" do
    step = layer(parse(render_chart(Chadcn::Chart::LineChart) { |chart| chart.line(data_key: :desktop, type: :step, dot: false) }), 400).at_css("path")["d"]

    assert_match(/\AM\d/, step)
    assert_not_includes step, "C"
    assert_raises(ArgumentError) { Chadcn::Chart::Line.new(data_key: :desktop, type: :zigzag) }
  end

  test "a line label list writes the value above each point" do
    doc = parse(render_chart(Chadcn::Chart::LineChart, margin: { top: 20 }) do |chart|
      chart.line(data_key: :desktop) { |line| line.label_list(position: :top, offset: 8) }
    end)
    texts = layer(doc, 2000).css(".recharts-label-list text")

    assert_equal 6, texts.size
    assert_equal %w[0 0], [ texts.first["width"], texts.first["height"] ]
    assert_equal "186", texts.first.text
  end

  test "reference lines are drawn with the lines, discarded outside the axis range" do
    doc = parse(render_chart(Chadcn::Chart::LineChart) do |chart|
      chart.y_axis
      chart.x_axis(data_key: :month)
      chart.reference_line(y: 200, stroke: "red", stroke_dasharray: "4 4")
      chart.reference_line(y: 5000, stroke: "blue")
      chart.reference_line(x: "March", stroke: "green")
      chart.line(data_key: :desktop)
    end)
    lines = layer(doc, 400).css(".recharts-reference-line line")

    assert_equal 2, lines.size
    assert_equal [ "4 4", "red", "200" ], values(lines.first, "stroke-dasharray", "stroke", "y")
    assert_equal lines.first["y1"], lines.first["y2"]
    assert_equal lines.last["x1"], lines.last["x2"]
  end

  test "if_overflow extend_domain widens the axis to include the reference line" do
    doc = parse(render_chart(Chadcn::Chart::LineChart) do |chart|
      chart.y_axis
      chart.reference_line(y: 999, if_overflow: :extend_domain)
      chart.line(data_key: :desktop)
    end)

    assert_equal "1000", layer(doc, 2000).css(".recharts-yAxis-tick-labels text").last.text
    assert_equal 1, layer(doc, 400).css(".recharts-reference-line").size
  end

  test "a reference line needs x: or y:, and an overflow it knows" do
    assert_raises(ArgumentError) { Chadcn::Chart::ReferenceLine.new }
    assert_raises(ArgumentError) { Chadcn::Chart::ReferenceLine.new(y: 1, if_overflow: :wander) }
  end

  test "hidden series and unknown options" do
    assert_empty parse(render_chart(Chadcn::Chart::LineChart) { |chart| chart.line(data_key: :desktop, hide: true) }).css("path.recharts-line-curve")
    assert_raises(ArgumentError) { Chadcn::Chart::Line.new }
    assert_raises(ArgumentError) { Chadcn::Chart::Line.new(data_key: :a, legend_type: :blob) }
    assert_raises(ArgumentError) { Chadcn::Chart::Line.new(data_key: :a, tooltip_type: :loud) }
  end
end

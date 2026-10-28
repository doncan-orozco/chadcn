# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::AreaChartTest < Chadcn::TestCase
  include ChartHelper

  def stacked(**props)
    render_chart(Chadcn::Chart::AreaChart, margin: { left: 12, right: 12 }, **props) do |chart|
      chart.x_axis(data_key: :month, tick_line: false, axis_line: false, tick_margin: 10, tick_formatter: SLICE)
      chart.area(data_key: :mobile, type: :natural, fill: "var(--color-mobile)", fill_opacity: 0.4, stroke: "var(--color-mobile)", stack_id: "a")
      chart.area(data_key: :desktop, type: :natural, fill: "var(--color-desktop)", fill_opacity: 0.4, stroke: "var(--color-desktop)", stack_id: "a")
    end
  end

  test "draws each area as the nesting recharts writes: a fill path and a stroke path" do
    doc = parse(stacked)
    areas = layer(doc, 100).css("g.recharts-area")
    fill, line = areas.first.css("path")

    assert_equal 2, areas.size
    assert_equal "g.recharts-layer > g.recharts-layer[clip-path] > g.recharts-layer", %w[g.recharts-layer g.recharts-layer[clip-path] g.recharts-layer].join(" > ")
    assert_match(/animationClipPath-recharts-area-chart-t-0/, areas.first.at_css("g[clip-path]")["clip-path"])
    assert_equal [ "recharts-curve recharts-area-area", "none", "var(--color-mobile)", "0.4" ], values(fill, "class", "stroke", "fill", "fill-opacity")
    assert_equal [ "recharts-curve recharts-area-curve", "none", "var(--color-mobile)" ], values(line, "class", "fill", "stroke")
    assert fill["d"].start_with?("M12,147.333C31.733,129.656,51.467,111.978,71.2,113.333")
  end

  test "stacked areas share the edge: the upper one starts where the lower one ends" do
    doc = parse(stacked)
    lower_curve = layer(doc, 100).css("g.recharts-area")[0].at_css("path.recharts-area-curve")["d"]
    upper_fill = layer(doc, 100).css("g.recharts-area")[1].at_css("path.recharts-area-area")["d"]

    assert_includes upper_fill, lower_curve.split("C").last.split(",").last(2).join(",")
    assert_operator upper_fill.size, :>, lower_curve.size
  end

  test "stroke none draws only the fill" do
    doc = parse(render_chart(Chadcn::Chart::AreaChart) { |chart| chart.area(data_key: :desktop, stroke: "none") })

    assert_equal 1, layer(doc, 100).css("path").size
  end

  test "dots are drawn in the dots layer with the area class" do
    doc = parse(render_chart(Chadcn::Chart::AreaChart) { |chart| chart.area(data_key: :desktop, dot: true) })

    assert_equal 6, layer(doc, 600).css("circle.recharts-area-dot").size
    assert_equal "recharts-layer recharts-area-dots", layer(doc, 600).at_css("g")["class"]
  end

  test "base_value moves the baseline of an area that is not stacked" do
    zero = parse(render_chart(Chadcn::Chart::AreaChart) { |chart| chart.area(data_key: :desktop) })
    top = parse(render_chart(Chadcn::Chart::AreaChart, base_value: :data_max) { |chart| chart.area(data_key: :desktop) })

    assert_match(/L315,195L/, layer(zero, 100).at_css("path.recharts-area-area")["d"])
    assert_match(/L315,5L/, layer(top, 100).at_css("path.recharts-area-area")["d"])
  end

  test "stack_offset expand normalizes every column to 1" do
    doc = parse(stacked(stack_offset: :expand).sub("</svg>", "</svg>"))
    top_edge = layer(doc, 100).css("g.recharts-area")[1].at_css("path.recharts-area-curve")["d"]

    assert_match(/\AM12,0C/, top_edge)
  end

  test "a range value draws the lower edge too" do
    rows = ROWS.map { |row| row.merge(desktop: [ row[:desktop] - 30, row[:desktop] + 30 ]) }
    paths = layer(parse(render_chart(Chadcn::Chart::AreaChart, data: rows) { |chart| chart.area(data_key: :desktop) }), 100).css("path")

    assert_equal 3, paths.size
    assert_equal [ "recharts-curve recharts-area-curve" ] * 2, paths.to_a.last(2).map { |path| path["class"] }
  end

  test "a vertical area chart lays the areas out along the y axis" do
    html = render_chart(Chadcn::Chart::AreaChart, layout: :vertical) do |chart|
      chart.x_axis(type: :number)
      chart.y_axis(data_key: :month, type: :category, tick_formatter: SLICE)
      chart.area(data_key: :desktop, type: :monotone)
    end
    path = layer(parse(html), 100).at_css("path.recharts-area-area")["d"]

    assert_match(/\AM/, path)
    assert_match(/Z\z/, path)
  end

  test "unknown options raise" do
    assert_raises(ArgumentError) { Chadcn::Chart::Area.new }
    assert_raises(ArgumentError) { Chadcn::Chart::Area.new(data_key: :a, type: :blob) }
    assert_raises(ArgumentError) { Chadcn::Chart::Bar.new(data_key: :a, radius: "round") }
    assert_raises(ArgumentError) { Chadcn::Chart::Bar.new(data_key: :a, active_bar: true) }
  end
end

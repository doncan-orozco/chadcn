# frozen_string_literal: true

require_relative "chart_helper"

class Chadcn::Chart::Cartesian::SurfaceTest < Chadcn::TestCase
  include ChartHelper

  test "the layers hold what recharts puts in them: grid, areas, bars, lines and reference lines, axes, dots, labels" do
    doc = parse(render_chart(Chadcn::Chart::LineChart) do |chart|
      chart.cartesian_grid
      chart.x_axis(data_key: :month)
      chart.reference_line(y: 100)
      chart.line(data_key: :desktop)
    end)

    assert layer(doc, -100).at_css(".recharts-cartesian-grid")
    assert layer(doc, 400).at_css(".recharts-line")
    assert layer(doc, 400).at_css(".recharts-reference-line")
    assert layer(doc, 500).at_css(".recharts-xAxis")
    assert layer(doc, 600).at_css(".recharts-line-dots")
    assert layer(doc, 2000).at_css(".recharts-xAxis-tick-labels")
    [ -50, 100, 200, 300, 1000, 1100, 1200 ].each { |z| assert_empty layer(doc, z).element_children, "layer #{z} should be empty" }
  end

  test "the axis group carries its class and the tick lines follow the tick setting" do
    html = render_chart do |chart|
      chart.x_axis(data_key: :month, class: "my-axis", tick_line: { stroke: "red" }, axis_line: { stroke_width: 3 }, name: "months", tick_formatter: SLICE)
      chart.bar(data_key: :desktop)
    end
    group = layer(parse(html), 500).at_css("g.recharts-xAxis")

    assert_equal "recharts-layer recharts-cartesian-axis recharts-xAxis xAxis my-axis", group["class"]
    assert_equal %w[3 months], values(group.at_css("line.recharts-cartesian-axis-line"), "stroke-width", "name")
    assert_equal 6, group.css("line.recharts-cartesian-axis-tick-line").size
    assert_equal "red", group.at_css("line.recharts-cartesian-axis-tick-line")["stroke"]
  end

  test "ticks on the top and right orientations, mirrored, put their labels on the matching side" do
    html = render_chart do |chart|
      chart.x_axis(data_key: :month, orientation: :top)
      chart.y_axis(orientation: :right)
      chart.bar(data_key: :desktop)
    end
    doc = parse(html)
    x_label = layer(doc, 2000).at_css(".recharts-xAxis-tick-labels text")
    y_label = layer(doc, 2000).at_css(".recharts-yAxis-tick-labels text")

    assert_equal %w[middle 0em], [ x_label["text-anchor"], x_label.at_css("tspan")["dy"] ]
    assert_equal [ "start", "0.355em" ], [ y_label["text-anchor"], y_label.at_css("tspan")["dy"] ]
  end

  test "an angle rotates the labels about their point" do
    html = render_chart do |chart|
      chart.x_axis(data_key: :month, angle: 45, tick_formatter: SLICE)
      chart.bar(data_key: :desktop)
    end

    assert_match(/\Arotate\(45, [\d.]+, [\d.]+\)\z/, layer(parse(html), 2000).at_css("text")["transform"])
  end

  test "a unit is appended to every label and a tick Hash styles them" do
    html = render_chart do |chart|
      chart.x_axis(data_key: :month, unit: "!", tick: { fill: "red", class: "lbl" }, tick_formatter: SLICE)
      chart.bar(data_key: :desktop)
    end
    label = layer(parse(html), 2000).at_css("text")

    assert_equal "Jan!", label.text
    assert_equal [ "red", "recharts-text recharts-cartesian-axis-tick-value lbl" ], values(label, "fill", "class")
  end

  test "long labels with spaces are broken into lines" do
    rows = [ { name: "New York City", v: 1 }, { name: "Los Angeles", v: 2 } ]
    html = render_chart(data: rows) do |chart|
      chart.y_axis(data_key: :name, type: :category)
      chart.bar(data_key: :v)
    end
    texts = layer(parse(html), 2000).css(".recharts-yAxis-tick-labels text")

    assert_equal [ "New York", "City" ], texts.first.css("tspan").map(&:text)
    assert_equal "1em", texts.first.css("tspan").last["dy"]
  end

  test "the grid can stripe its bands and draw a background" do
    html = render_chart do |chart|
      chart.cartesian_grid(horizontal_fill: [ "#eee", "#fff" ], vertical_fill: [ "#ddd" ], fill: "#fafafa", stroke_dasharray: "3 3", class: "grid-line")
      chart.bar(data_key: :desktop)
    end
    grid = layer(parse(html), -100).at_css("g.recharts-cartesian-grid")

    assert_equal "#fafafa", grid.at_css("> rect.recharts-cartesian-grid-bg")["fill"]
    assert_equal [ "#eee", "#fff", "#eee", "#fff" ], grid.css(".recharts-cartesian-gridstripes-horizontal rect").map { |rect| rect["fill"] }.first(4)
    assert_equal [ "3 3", "grid-line" ], values(grid.at_css("line"), "stroke-dasharray", "class")
  end

  test "allow_data_overflow clips the shapes of the series to the plot" do
    html = render_chart(Chadcn::Chart::LineChart) do |chart|
      chart.y_axis(domain: [ 0, 250 ], allow_data_overflow: true)
      chart.line(data_key: :desktop, dot: { clip_dot: false })
    end
    doc = parse(html)
    line = layer(doc, 400).at_css("g.recharts-line")

    assert line.at_css("defs clipPath[id^='clipPath-']")
    assert line.at_css("defs clipPath[id^='clipPath-dots-']")
    assert_match(/\Aurl\(#clipPath-recharts-line/, line.at_css("path")["clip-path"])
    assert_match(/\Aurl\(#clipPath-dots-/, layer(doc, 600).at_css("g")["clip-path"])
  end

  test "a standalone label is drawn around the plot" do
    html = render_chart do |chart|
      chart.label(value: "Target", position: :top, class: "fill-foreground")
      chart.bar(data_key: :desktop)
    end
    label = layer(parse(html), 2000).at_css("text.fill-foreground")

    assert_equal "Target", label.text
    assert_equal "recharts-text fill-foreground", label["class"]
  end
end

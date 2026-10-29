# frozen_string_literal: true

require_relative "polar/polar_helper"

class Chadcn::Chart::RadarChartTest < Chadcn::TestCase
  include PolarHelper

  POLYGON = "M160,55.825L222.7327,63.7813L208.7464,128.1438L160,117.3375L117.0127,124.8188L115.9843,74.5875L160,55.825Z"

  def default_chart(**props)
    render_radar(chart: props) do |chart|
      chart.polar_angle_axis(data_key: :month)
      chart.polar_grid
      chart.radar(data_key: :desktop, fill: "var(--color-desktop)", fill_opacity: 0.6)
    end
  end

  test "draws the radar polygon through one point per category, from the top, clockwise, in the area layer" do
    doc = parse(default_chart)
    polygon = layer(doc, 100).at_css("> g.recharts-radar > g.recharts-radar-polygon > path")

    assert_equal POLYGON, polygon["d"]
    assert_equal [ "recharts-polygon", "var(--color-desktop)", "0.6" ], values(polygon, "class", "fill", "fill-opacity")
    assert_equal "recharts-radar-chart-t-0", polygon["id"]
    assert_nil polygon["stroke"]
    assert_equal "recharts-layer recharts-radar", layer(doc, 100).at_css("> g")["class"]
  end

  test "the grid has a ring and a line from the center for every tick of the axes, in the lowest layer" do
    group = layer(parse(default_chart), -100).at_css("> g.recharts-polar-grid")
    rings = group.css("> g.recharts-polar-grid-concentric > path")
    lines = group.css("> g.recharts-polar-grid-angle > line")

    assert_equal(%w[0 19 38 57 76], rings.map { |ring| ring["radius"] })
    assert_equal "recharts-polar-grid-concentric-polygon", rings.first["class"]
    assert_equal "M 160,81L 176.45448267190434,90.5L 176.45448267190434,109.5L 160,119L 143.54551732809566,109.5L 143.54551732809566,90.5Z", rings[1]["d"]
    assert_equal [ "#ccc", "none" ], values(rings.first, "stroke", "fill")
    assert_equal 6, lines.size
    assert_equal %w[160 100 160 24], values(lines.first, "x1", "y1", "x2", "y2")
    assert_nil lines.first["class"]
  end

  test "the angle axis draws its line through the ticks and a line and a label at every category" do
    axis = layer(parse(default_chart), 500).at_css("> g.recharts-polar-angle-axis")
    line = axis.at_css("> path")
    ticks = axis.css("> g.recharts-polar-angle-axis-ticks > g.recharts-polar-angle-axis-tick")
    labels = ticks.map { |tick| tick.at_css("text") }

    assert_equal %w[recharts-layer recharts-polar-angle-axis angleAxis], axis["class"].split
    assert_equal [ "recharts-polygon recharts-polar-angle-axis-line", "none", "outer", "76", "0" ],
                 values(line, "class", "fill", "orientation", "radius", "angle")
    assert_equal "M160,24L225.8179,62L225.8179,138L160,176L94.1821,138L94.1821,62L160,24Z", line["d"]
    assert_equal %w[January February March April May June], labels.map(&:text)
    assert_equal(%w[middle start start middle end end], labels.map { |label| label["text-anchor"] })
    assert_equal(%w[0em 0.355em 0.355em 0.71em 0.355em 0.355em], labels.map { |label| label.at_css("tspan")["dy"] })
    assert_equal %w[160 24 160 16], values(ticks.first.at_css("line"), "x1", "y1", "x2", "y2")
    assert_equal [ "recharts-text recharts-polar-angle-axis-tick-value", "none", "#808080" ], values(labels.first, "class", "stroke", "fill")
  end

  test "the radius axis, declared, draws its line, ticks and rotated labels at its angle" do
    html = render_radar do |chart|
      chart.polar_angle_axis(data_key: :month)
      chart.polar_radius_axis(angle: 90, tick_count: 3, domain: [ 0, 400 ])
      chart.radar(data_key: :desktop)
    end
    axis = layer(parse(html), 500).at_css("> g.recharts-polar-radius-axis")
    texts = axis.css("text")

    assert_equal %w[recharts-layer recharts-polar-radius-axis radiusAxis], axis["class"].split
    assert_equal %w[0 200 400], texts.map(&:text)
    assert_equal [ "recharts-polar-radius-axis-line", "#ccc" ], values(axis.at_css("> line"), "class", "stroke")
    assert_equal [ "start", "rotate(0, 160, 100)", "#ccc" ], values(texts.first, "text-anchor", "transform", "fill")
    assert_equal %w[160 24], values(axis.at_css("> line"), "x2", "y2")
  end

  test "dots are drawn in the scatter layer on request, with the attributes of the dot winning" do
    html = render_radar do |chart|
      chart.polar_angle_axis(data_key: :month)
      chart.radar(data_key: :desktop, fill: "var(--color-desktop)", fill_opacity: 0.6, dot: { r: 4, fill_opacity: 1 })
    end
    dots = layer(parse(html), 600).css("> g.recharts-radar-dots > circle")

    assert_equal 6, dots.size
    assert_equal [ "recharts-dot recharts-radar-dot", "4", "1", "var(--color-desktop)" ], values(dots.first, "class", "r", "fill-opacity", "fill")
    assert_equal %w[160 55.824999999999996], values(dots.first, "cx", "cy")
    assert_empty layer(parse(default_chart), 600).children
  end

  test "a label list labels the points, in the label layer, in the label font" do
    html = render_radar do |chart|
      chart.polar_angle_axis(data_key: :month)
      chart.radar(data_key: :desktop) { |radar| radar.label_list(data_key: :desktop, position: :top, fill: "black") }
    end
    texts = layer(parse(html), 2000).css("> g.recharts-label-list > text")

    assert_equal %w[186 305 237 73 209 214], texts.map(&:text)
    assert_equal %w[0 0 black middle], values(texts.first, "width", "height", "fill", "text-anchor")
    assert_equal "50.824999999999996", texts.first["y"]
  end

  test "the legend lists the radar and takes its room at the bottom" do
    html = render_radar do |chart|
      chart.legend(content: Chadcn::Chart::Legend::Content.new)
      chart.radar(data_key: :desktop, fill: "var(--color-desktop)")
    end
    doc = parse(html)

    assert_equal "Desktop", doc.at_css(".recharts-legend-wrapper").text
    assert_equal "162", doc.at_css("clipPath rect")["height"]
  end

  test "nothing to draw is the empty groups: no data, a hidden radar" do
    empty = parse(render_radar(chart: { data: [] }) { |chart| chart.radar(data_key: :desktop) })
    hidden = parse(render_radar { |chart| chart.radar(data_key: :desktop, hide: true) })

    assert_empty layer(empty, 100).children
    assert_empty layer(hidden, 100).children
  end

  test "a missing value puts the point at the center, a range is refused" do
    rows = [ { month: "A", desktop: 10 }, { month: "B", desktop: nil }, { month: "C", desktop: 30 } ]
    doc = parse(render_radar(chart: { data: rows }) { |chart| chart.radar(data_key: :desktop, dot: true) })
    dots = layer(doc, 600).css("circle")

    assert_equal %w[160 100], values(dots[1], "cx", "cy")
    assert_raises(ArgumentError) { render_radar(chart: { data: [ { month: "A", desktop: [ 1, 5 ] } ] }) { |chart| chart.radar(data_key: :desktop) } }
  end

  test "the start and end angles turn the chart: counterclockwise from the right" do
    doc = parse(default_chart(start_angle: 0, end_angle: 360))
    labels = layer(doc, 500).css("text")

    assert_equal(%w[start start start end end end], labels.map { |label| label["text-anchor"] })
    assert_equal %w[202 172.74613391789285], values(labels.first, "x", "y")
    assert_equal "M182.0875,61.7433L123.7813,37.2673L103.7125,100L151.3312,115.0147L184.8188,142.9873L210.825,100L182.0875,61.7433Z", layer(doc, 100).at_css("path")["d"]
  end

  test "ids are unique per chart and the center is written on the svg" do
    doc = parse(default_chart)

    assert_equal "chart-t-clip", doc.at_css("clipPath")["id"]
    assert_equal %w[50% 50%], values(doc.at_css("svg"), "cx", "cy")
  end

  test "a radar chart refuses a pie, a radial bar and a bad chart option" do
    assert_raises(ArgumentError) { render_radar(&:pie) }
    assert_raises(ArgumentError) { render_radar { |chart| chart.radial_bar(data_key: :desktop) } }
    assert_raises(ArgumentError) { Chadcn::Chart::RadarChart.new(data: [ 1 ]) }
    assert_raises(ArgumentError) { Chadcn::Chart::RadarChart.new(inner_radius: "inner") }
  end

  test "the radar chart starts at the top and runs clockwise, and the radar chart classes load in a fresh process" do
    script = <<~RUBY
      require "chadcn"
      puts Chadcn::Chart::RadarChart.instance_method(:initialize).parameters.assoc(:key).inspect.include?(":data")
      html = Class.new(Phlex::HTML) { define_method(:view_template) { render(Chadcn::Chart::RadarChart.new(data: [ { a: "x", b: 1 }, { a: "y", b: 2 } ])) { |chart| chart.polar_angle_axis(data_key: :a); chart.radar(data_key: :b) } } }.new.call
      puts html.include?("recharts-radar-polygon")
    RUBY
    output = IO.popen([ RbConfig.ruby, "-I", File.expand_path("../../../lib", __dir__), "-e", script ], err: %i[child out], &:read)

    assert_equal %w[true true], output.lines.map(&:strip).last(2), output
  end
end

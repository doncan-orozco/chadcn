# frozen_string_literal: true

require_relative "chart_helper"

class Chadcn::Chart::Cartesian::TooltipPlanTest < Chadcn::TestCase
  include ChartHelper

  TooltipContent = Chadcn::Chart::Tooltip::Content

  def render_tooltip(chart_class = Chadcn::Chart::BarChart, tooltip: {}, rows: ROWS, **props, &block)
    block ||= ->(chart) { chart.bar(data_key: :desktop, fill: "var(--color-desktop)") }
    render_chart(chart_class, data: rows, **props) do |chart|
      chart.x_axis(data_key: :month)
      chart.tooltip(content: TooltipContent.new, **tooltip)
      block.call(chart)
    end
  end

  def templates(html) = parse(html).css("template[data-chadcn--chart-target=tooltipTemplate]")

  def json(node, name) = JSON.parse(node[name])

  test "writes one inert template per category, after the responsive shell, as children of the chart" do
    doc = parse(render_tooltip)
    chart = doc.at_css("[data-slot=chart]")

    assert_equal %w[style div], chart.element_children.first(2).map(&:name)
    assert_equal [ "template" ] * 6, chart.element_children.to_a.last(6).map(&:name)
    assert_equal((0..5).map(&:to_s), templates(doc.to_html).map { |node| node["data-index"] })
    assert_equal(%w[January February March April May June], templates(doc.to_html).map { |node| node["data-label"] })
  end

  test "a template holds the content for the payload of exactly the declared series, in declaration order, with the color each resolves" do
    html = render_tooltip do |chart|
      chart.bar(data_key: :mobile, fill: "var(--color-mobile)")
      chart.bar(data_key: :desktop, fill: "var(--color-desktop)")
    end
    second = templates(html)[1]
    rows = second.css("div.grid > div.flex.w-full")

    assert_equal(%w[Mobile Desktop], rows.map { |row| row.at_css("span.text-muted-foreground").text })
    assert_equal(%w[200 305], rows.map { |row| row.at_css("span.font-mono").text })
    assert_includes rows.first.at_css("div.shrink-0")["style"], "--color-bg: var(--color-mobile);"
    assert_equal "February", second.at_css("div.font-medium").text
  end

  test "a series with tooltip_type none is kept in the template for the content to drop, a null value and a hidden series are filtered" do
    rows = ROWS.map.with_index { |row, index| index == 1 ? row.merge(mobile: nil) : row }
    html = render_tooltip(rows: rows) do |chart|
      chart.bar(data_key: :desktop, fill: "red", tooltip_type: :none)
      chart.bar(data_key: :mobile, fill: "blue")
      chart.bar(data_key: :desktop, name: "hidden", hide: true)
    end
    spans = ->(index) { templates(html)[index].css("span.text-muted-foreground").map(&:text) }

    assert_equal [ "Mobile" ], spans.call(0)
    assert_empty spans.call(1)

    shown = render_tooltip(tooltip: { include_hidden: true }) { |chart| chart.bar(data_key: :desktop, name: "Hidden one", hide: true) }

    assert_equal [ "Hidden one" ], templates(shown)[0].css("span.text-muted-foreground").map(&:text)
  end

  test "default_index renders the wrapper visible with the content, and the hidden empty wrapper without it" do
    shown = parse(render_tooltip(tooltip: { default_index: 1 })).at_css(".recharts-tooltip-wrapper")
    hidden = parse(render_tooltip).at_css(".recharts-tooltip-wrapper")

    assert_equal %w[http://www.w3.org/1999/xhtml -1], [ shown["xmlns"], shown["tabindex"] ]
    assert_equal "transition: transform 400ms; visibility: visible; pointer-events: none; position: absolute; top: 0px; left: 0px;", shown["style"]
    assert_equal "February", shown.at_css("div.font-medium").text
    assert_equal "visibility: hidden; pointer-events: none; position: absolute; top: 0px; left: 0px;", hidden["style"]
    assert_empty hidden.children
  end

  test "active false never shows, wrapper_style wins last, and an animation off drops the transition" do
    never = parse(render_tooltip(tooltip: { default_index: 1, active: false })).at_css(".recharts-tooltip-wrapper")
    styled = parse(render_tooltip(tooltip: { default_index: 1, is_animation_active: false, wrapper_style: { z_index: 9, visibility: "hidden" },
                                             class: "extra" }))
             .at_css(".recharts-tooltip-wrapper")

    assert_empty never.children
    assert_includes never["style"], "visibility: hidden"
    assert_equal "visibility: hidden; pointer-events: none; position: absolute; top: 0px; left: 0px; z-index: 9;", styled["style"]
    assert_equal "recharts-tooltip-wrapper extra", styled["class"]
  end

  test "a bar chart draws the cursor rectangle behind the bars at the default index, a line chart the cursor line and the active dots" do
    bar = parse(render_tooltip(tooltip: { default_index: 1 }))
    cursor = bar.at_css("g.recharts-zIndex-layer_200 path.recharts-tooltip-cursor")

    assert_equal %w[56.6667 5.5 51.6667 159 #ccc none], values(cursor, "x", "y", "width", "height", "fill", "stroke")
    assert_equal "M 56.6667,5.5 h 51.6667 v 159 h -51.6667 Z", cursor["d"]
    assert_equal "recharts-rectangle recharts-tooltip-cursor", cursor["class"]

    line = parse(render_tooltip(Chadcn::Chart::LineChart, tooltip: { default_index: 1 }) { |chart| chart.line(data_key: :desktop, stroke: "red") })
    line_cursor = line.at_css("g.recharts-zIndex-layer_1100 path.recharts-tooltip-cursor")
    dot = line.at_css("g.recharts-zIndex-layer_1200 g.recharts-active-dot circle")

    assert_equal "recharts-curve recharts-tooltip-cursor", line_cursor["class"]
    assert_equal %w[4 red #fff 2], values(dot, "r", "fill", "stroke", "stroke-width")
    assert_nil line.at_css("g.recharts-zIndex-layer_200 path")
  end

  test "cursor false draws and ships none, a Hash adds attributes, active_dot false drops the dot" do
    without = parse(render_tooltip(tooltip: { default_index: 1, cursor: false }))
    custom = parse(render_tooltip(Chadcn::Chart::LineChart,
                                  tooltip: { default_index: 1, cursor: { stroke: "red", stroke_dasharray: "3 3", class: "mine" } }) do |chart|
      chart.line(data_key: :desktop, active_dot: false)
    end)
    cursor = custom.at_css("path.recharts-tooltip-cursor")

    assert_nil without.at_css(".recharts-tooltip-cursor")
    assert_nil json_or_nil(templates(without.to_html).first, "data-cursor")
    assert_equal [ "red", "3 3", "recharts-curve recharts-tooltip-cursor mine" ], values(cursor, "stroke", "stroke-dasharray", "class")
    assert_nil custom.at_css(".recharts-active-dot")
  end

  def json_or_nil(node, name) = node[name] && json(node, name)

  test "data attributes carry the anchor, the cursor geometry and the active dots of the index" do
    html = render_tooltip(Chadcn::Chart::LineChart) { |chart| chart.line(data_key: :desktop, stroke: "red") }
    second = templates(html)[1]
    cursor = json(second, "data-cursor")

    assert_equal({ "x" => 67, "y" => 102.5 }, json(second, "data-coordinate"))
    assert_equal "path", cursor["tag"]
    assert_equal "M67,5L67,165", cursor["attrs"]["d"]
    assert_equal [ { "cx" => "67", "cy" => "12.5", "r" => "4", "fill" => "red", "stroke" => "#fff", "stroke-width" => "2" } ], json(second, "data-active-dots")
  end

  test "a vertical layout follows the category axis down the y axis" do
    html = render_chart(Chadcn::Chart::BarChart, layout: :vertical) do |chart|
      chart.y_axis(data_key: :month, type: :category)
      chart.x_axis(type: :number)
      chart.tooltip(content: TooltipContent.new, default_index: 0)
      chart.bar(data_key: :desktop, fill: "red")
    end
    first = templates(html).first
    cursor = parse(html).at_css("path.recharts-tooltip-cursor")

    assert_in_delta 160.0, json(first, "data-coordinate")["x"], 40.0
    assert_equal "January", first["data-label"]
    assert_equal "recharts-rectangle recharts-tooltip-cursor", cursor["class"]
  end

  test "a < in a category name is escaped in the label attribute, the content and the visible wrapper" do
    rows = [ { month: "A<b>", desktop: 1 }, { month: "C&D", desktop: 2 } ]
    html = render_tooltip(rows: rows, tooltip: { default_index: 0 })

    assert_nil parse(html).at_css("b")
    assert_equal([ "A<b>", "C&D" ], templates(html).map { |node| node["data-label"] })
    assert_equal "A<b>", parse(html).at_css(".recharts-tooltip-wrapper div.font-medium").text
  end

  test "named formatters of the tooltip format the label and the values" do
    html = render_tooltip(tooltip: { default_index: 1, label_formatter: { slice: [ 0, 3 ] }, formatter: :locale }) do |chart|
      chart.bar(data_key: :desktop, fill: "red")
    end

    assert_equal "Feb", parse(html).at_css(".recharts-tooltip-wrapper div.font-medium").text
  end

  test "a tooltip without content ships no templates and an empty wrapper, and a tooltip written outside a chart is refused" do
    html = render_chart do |chart|
      chart.tooltip(default_index: 1)
      chart.bar(data_key: :desktop)
    end

    assert_empty parse(html).css("template")
    assert_empty parse(html).at_css(".recharts-tooltip-wrapper").children
    assert_raises(ArgumentError) { Chadcn::Chart::Tooltip.new.call }
  end
end

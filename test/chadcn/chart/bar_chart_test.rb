# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::BarChartTest < Chadcn::TestCase
  include ChartHelper

  Z_ORDER = %w[-100 -50 100 200 300 400 500 600 1000 1100 1200 2000].freeze

  def default_chart(**props)
    render_chart(**props) do |chart|
      chart.cartesian_grid(vertical: false)
      chart.x_axis(data_key: :month, tick_line: false, tick_margin: 10, axis_line: false, tick_formatter: SLICE)
      chart.bar(data_key: :desktop, fill: "var(--color-desktop)", radius: 4)
    end
  end

  test "draws recharts' shell: wrapper, svg, the layers in order and the clip path after the second" do
    doc = parse(default_chart)
    wrapper = doc.at_css(".recharts-wrapper")
    surface = wrapper.at_css("> svg.recharts-surface")

    assert_equal "320", wrapper["width"]
    assert_equal "position: relative; cursor: default; width: 320px; height: 200px;", wrapper["style"]
    assert_equal %w[application 0], [ surface["role"], surface["tabindex"] ]
    assert_equal "0 0 320 200", surface["viewBox"]
    assert_equal %w[title desc], surface.element_children.first(2).map(&:name)
    assert_equal Z_ORDER, surface.css("> g").map { |node| node["class"].delete_prefix("recharts-zIndex-layer_") }
    assert_equal "defs", surface.element_children[4].name
    clip = surface.at_css("> defs clipPath rect")

    assert_equal %w[5 5 160 310], values(clip, "x", "y", "height", "width")
  end

  test "lays the bars out like recharts: band, category gap and integer width" do
    doc = parse(default_chart)
    first = bars(doc).first

    assert_equal 6, bars(doc).size
    assert_equal %w[10.1667 72 41 93], values(first, "x", "y", "width", "height")
    assert_equal "var(--color-desktop)", first["fill"]
    assert_equal "4", first["radius"]
    assert_equal "undefined", first["name"]
    assert_equal "M 10.1667,76\n            A 4,4,0,0,1,14.1667,72\n            L 47.1667,72\n            A 4,4,0,0,1,51.1667,76\n            L 51.1667,161\n            A 4,4,0,0,1,47.1667,165\n            L 14.1667,165\n            A 4,4,0,0,1,10.1667,161 Z", first["d"]
  end

  test "draws the horizontal grid lines at the nice ticks of the value axis and the labels through the formatter" do
    doc = parse(default_chart)
    lines = layer(doc, -100).css(".recharts-cartesian-grid-horizontal line")
    labels = layer(doc, 2000).css(".recharts-cartesian-axis-tick-value")

    assert_equal %w[165 125 85 45 5], lines.map { |line| line["y1"] }
    assert_nil layer(doc, -100).at_css(".recharts-cartesian-grid-vertical")
    assert_equal %w[Jan Feb Mar Apr May Jun], labels.map(&:text)
    assert_equal %w[30.833333333333332 181 middle], values(labels.first, "x", "y", "text-anchor")
    assert_equal "0.71em", labels.first.at_css("tspan")["dy"]
    assert_nil layer(doc, 500).at_css(".recharts-cartesian-axis-line")
  end

  test "stacks bars that share a stack_id, with array radius on the corners" do
    html = render_chart do |chart|
      chart.x_axis(data_key: :month, tick_line: false, axis_line: false)
      chart.bar(data_key: :desktop, stack_id: "a", fill: "red", radius: [ 0, 0, 4, 4 ])
      chart.bar(data_key: :mobile, stack_id: "a", fill: "blue", radius: [ 4, 4, 0, 0 ])
    end
    doc = parse(html)
    bottom = bars(doc, 0).first
    top = bars(doc, 1).first

    assert_equal %w[10.1667 115.4 41 49.6], values(bottom, "x", "y", "width", "height")
    assert_equal bottom["x"], top["x"]
    assert_equal bottom["y"].to_f, top["y"].to_f + top["height"].to_f, 0.0001
    assert_nil bottom["radius"]
    assert_equal "M10.1667,115.4L 51.1667,115.4L 51.1667,161A 4,4,0,0,1,\n        47.1667,165L 14.1667,165A 4,4,0,0,1,\n        10.1667,161Z", bottom["d"]
  end

  test "a negative bar is drawn from the zero line, its height negative" do
    rows = [ { month: "A", desktop: 120 }, { month: "B", desktop: -80 } ]
    doc = parse(render_chart(data: rows) { |chart| chart.bar(data_key: :desktop, radius: 4) })
    positive, negative = bars(doc)
    zero = values(positive, "y", "height").sum(&:to_f)

    assert_operator number(negative, "height"), :<, 0
    assert_in_delta zero, number(negative, "y") + number(negative, "height"), 0.0001
    assert_includes negative["d"], "A 4,4,0,0,0,"
  end

  test "a row without the data_key draws no bar and keeps the band of its category" do
    rows = [ { month: "A", desktop: 10 }, { month: "B" }, { month: "C", desktop: 30 } ]
    doc = parse(render_chart(data: rows) { |chart| chart.bar(data_key: :desktop) })

    assert_equal 2, bars(doc).size
    assert_in_delta 2 * 103.3333, number(bars(doc).last, "x") - number(bars(doc).first, "x"), 0.001
  end

  test "tick_formatter receives the value and the index, and its result is the label text" do
    seen = []
    html = render_chart do |chart|
      chart.x_axis(data_key: :month, tick_formatter: ->(value, index) { seen << [ value, index ] && "#{index}:#{value[0]}" })
      chart.bar(data_key: :desktop)
    end

    assert_equal %w[0:J 1:F 2:M 3:A 4:M 5:J], parse(html).css(".recharts-cartesian-axis-tick-value").map(&:text)
    assert_includes seen, [ "February", 1 ]
  end

  test "category names and titles from the caller are escaped" do
    rows = [ { month: "<b>", desktop: 1 }, { month: "A & B", desktop: 2 } ]
    html = render_chart(data: rows, title: "<b>x</b>") do |chart|
      chart.x_axis(data_key: :month)
      chart.bar(data_key: :desktop, name: "\"quoted\" <name>")
    end

    assert_not_includes html, "<b></tspan>"
    assert_includes html, "&lt;b&gt;"
    assert_includes html, "A &amp; B"
    assert_equal "<b>x</b>", parse(html).at_css("title").text
    assert_equal "\"quoted\" <name>", parse(html).at_css("path.recharts-rectangle")["name"]
  end

  test "a cell styles the rectangle at its index" do
    html = render_chart do |chart|
      chart.bar(data_key: :desktop, fill: "red") do |bar|
        bar.cell(fill: "blue")
        bar.cell(class: "fill-foreground", stroke: "green", data: { index: 1 })
      end
    end
    first, second, third = bars(parse(html))

    assert_equal [ "blue", "red" ], [ first["fill"], third["fill"] ]
    assert_equal "recharts-rectangle fill-foreground", second["class"]
    assert_equal %w[green 1], [ second["stroke"], second["data-index"] ]
  end

  test "a label list writes a text per bar in the labels layer, above the bar by default offset" do
    html = render_chart(margin: { top: 20 }) do |chart|
      chart.bar(data_key: :desktop) { |bar| bar.label_list(position: :top, offset: 12, class: "fill-foreground", font_size: 12) }
    end
    texts = layer(parse(html), 2000).css(".recharts-label-list text")

    assert_equal %w[186 305 237 73 209 214], texts.map(&:text)
    assert_equal "recharts-text fill-foreground", texts.first["class"]
    assert_equal %w[12 12 #808080 middle], values(texts.first, "offset", "font-size", "fill", "text-anchor")
    assert_equal "0em", texts.first.at_css("tspan")["dy"]
  end

  test "background draws a rectangle behind every bar in the lowest layer" do
    doc = parse(render_chart { |chart| chart.bar(data_key: :desktop, background: { fill: "#fafafa" }) })
    backs = layer(doc, -50).css("path.recharts-bar-background-rectangle")

    assert_equal 6, backs.size
    assert_equal "#fafafa", backs.first["fill"]
    assert_equal "M 10.1667,5 h 41 v 190 h -41 Z", backs.first["d"]
  end

  test "a vertical layout puts the categories on the y axis and grows the bars to the right" do
    html = render_chart(layout: :vertical, margin: { left: -20 }) do |chart|
      chart.x_axis(type: :number, data_key: :desktop, hide: true)
      chart.y_axis(data_key: :month, type: :category, tick_line: false, axis_line: false, tick_formatter: SLICE)
      chart.bar(data_key: :desktop, radius: 5)
    end
    first = bars(parse(html)).first

    assert_equal %w[40 3.3333 162.75 26], values(first, "x", "y", "width", "height")
  end

  test "accessibility_layer false drops role and tabindex; role, tab_index and other attributes go on the svg, class and style on the wrapper" do
    plain = parse(default_chart(accessibility_layer: false)).at_css("svg")

    assert_nil plain["role"]
    assert_nil plain["tabindex"]

    doc = parse(default_chart(role: "img", tab_index: 2, class: "extra", style: "color: red;", id: "chart-svg", "aria-label": "Sales"))
    surface = doc.at_css("svg.recharts-surface")

    assert_equal %w[img 2 chart-svg Sales], [ surface["role"], surface["tabindex"], surface["id"], surface["aria-label"] ]
    assert_equal "recharts-wrapper extra", doc.at_css(".recharts-wrapper")["class"]
    assert_equal "position: relative; cursor: default; width: 320px; height: 200px; color: red;", doc.at_css(".recharts-wrapper")["style"]
  end

  test "outside a container the chart wraps itself in the responsive shell at the default size" do
    doc = parse(render_bare_chart { |chart| chart.bar(data_key: :desktop) })

    assert_equal "320", doc.at_css(".recharts-responsive-container > div > .recharts-wrapper")["width"]
  end

  test "inside a container the chart takes its size and text metrics" do
    html = render_chart(container: { initial_dimension: { width: 400, height: 300 } }) { |chart| chart.bar(data_key: :desktop) }
    doc = parse(html)

    assert_equal %w[400 300], values(doc.at_css("svg.recharts-surface"), "width", "height")
    assert_equal 1, doc.css(".recharts-wrapper").size
  end

  test "markup the block writes lands in the svg after the clip path" do
    html = render_chart do |chart|
      chart.bar(data_key: :desktop)
      raw(safe("<defs><linearGradient id=\"g\"></linearGradient></defs>")) if false
    end
    assert_not_includes html, "linearGradient"

    marked = Class.new(Phlex::HTML) do
      def view_template
        render(Chadcn::Chart::Container.new(config: ChartHelper::CONFIG, id: "m")) do
          render(Chadcn::Chart::AreaChart.new(data: ChartHelper::ROWS)) do |chart|
            render Phlex::SVG.new { |svg| svg.defs { svg.linearGradient(id: "fill") } }
            chart.area(data_key: :desktop, fill: "url(#fill)")
          end
        end
      end
    end.new.call
    surface = parse(marked).at_css("svg.recharts-surface")

    assert_equal %w[defs defs], surface.element_children[4, 2].map(&:name)
    assert_equal "fill", surface.element_children[5].at_css("linearGradient")["id"]
  end

  test "a hidden bar draws nothing and takes no slot" do
    doc = parse(render_chart do |chart|
      chart.bar(data_key: :desktop, hide: true)
      chart.bar(data_key: :mobile)
    end)

    assert_equal 1, doc.css("g.recharts-bar").size
    assert_equal "41", bars(doc).first["width"]
  end

  test "bar_size and bar_gap place the bars side by side, centered in the band" do
    doc = parse(render_chart(bar_gap: 8) do |chart|
      chart.bar(data_key: :desktop, bar_size: 10)
      chart.bar(data_key: :mobile, bar_size: 20)
    end)

    assert_equal %w[10 20], [ bars(doc, 0).first["width"], bars(doc, 1).first["width"] ]
    assert_equal "11", bars(doc, 0).first["x"]
    assert_in_delta 18, number(bars(doc, 1).first, "x") - number(bars(doc, 0).first, "x"), 0.0001
  end

  test "max_bar_size narrows a bar and keeps it centered in its share of the band" do
    narrow, wide = %w[desktop mobile].zip([ 20, nil ]).map do |key, max|
      doc = parse(render_chart { |chart| chart.bar(data_key: key.to_sym, max_bar_size: max) })
      bars(doc).first
    end

    assert_equal "20", narrow["width"]
    assert_equal "41", wide["width"]
    assert_in_delta number(wide, "x") + 10.5, number(narrow, "x"), 0.0001
  end

  test "an invalid option raises instead of drawing something else" do
    assert_raises(ArgumentError) { Chadcn::Chart::BarChart.new(layout: :diagonal) }
    assert_raises(ArgumentError) { Chadcn::Chart::BarChart.new(stack_offset: :wiggle) }
    assert_raises(ArgumentError) { Chadcn::Chart::BarChart.new(data: "rows") }
    assert_raises(ArgumentError) { Chadcn::Chart::BarChart.new(margin: 5) }
    assert_raises(ArgumentError) { render_chart { |chart| chart.cell(fill: "red") } }
  end

  test "an empty chart still draws the shell and the grid edges" do
    doc = parse(render_chart(data: []) { |chart| chart.bar(data_key: :desktop) })

    assert_equal 12, doc.css("svg.recharts-surface > g").size
    assert_empty doc.css("path.recharts-rectangle")
  end
end

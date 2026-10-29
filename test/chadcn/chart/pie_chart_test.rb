# frozen_string_literal: true

require_relative "polar/polar_helper"

class Chadcn::Chart::PieChartTest < Chadcn::TestCase
  include PolarHelper

  Z_ORDER = %w[-100 -50 100 200 300 400 500 600 1000 1100 1200 2000].freeze

  test "draws recharts' shell: wrapper, svg with the center of the chart, the layers in order and the clip path after the second" do
    doc = parse(render_pie)
    wrapper = doc.at_css(".recharts-wrapper")
    surface = wrapper.at_css("> svg.recharts-surface")

    assert_equal "position: relative; cursor: default; width: 320px; height: 200px;", wrapper["style"]
    assert_equal [ "application", "0", "50%", "50%", "0 0 320 200" ], values(surface, "role", "tabindex", "cx", "cy", "viewBox")
    assert_equal %w[title desc], surface.element_children.first(2).map(&:name)
    assert_equal(Z_ORDER, surface.css("> g").map { |node| node["class"].delete_prefix("recharts-zIndex-layer_") })
    assert_equal %w[5 5 190 310], values(surface.at_css("> defs clipPath rect"), "x", "y", "height", "width")
  end

  test "lays the sectors out like recharts: counterclockwise from 3 o'clock, 80% of the largest circle" do
    paths = sectors(parse(render_pie))
    first = paths.first

    assert_equal 5, paths.size
    assert_equal %w[160 100 var(--color-chrome) #fff chrome -1 0], values(first, "cx", "cy", "fill", "stroke", "name", "tabindex", "data-recharts-item-index")
    assert_equal "recharts-sector", first["class"]
    assert_equal "M 236,100\n    A 76,76,0,\n    0,0,\n    137.7455,27.3313\n  L 160,100 Z", first["d"]
    assert_equal(%w[0 1 2 3 4], paths.map { |path| path["data-recharts-item-index"] })
    assert_equal 1, paths.map { |path| path["data-recharts-item-id"] }.uniq.size
  end

  test "each sector is in a pie-sector group with a shape group, the pie in the area layer" do
    doc = parse(render_pie)
    group = layer(doc, 100).at_css("> g.recharts-pie")

    assert_equal %w[recharts-layer recharts-pie], group["class"].split
    assert_equal "0", group["tabindex"]
    assert_equal 5, group.css("> g.recharts-layer > g.recharts-pie-sector[tabindex='-1'] > g.recharts-shape > path").size
  end

  test "a donut has a hole and a stroke width, and a label in the middle of the chart" do
    html = render_pie(inner_radius: 60, stroke_width: 5) { |pie| pie.label(value: "Visitors", position: :center) }
    doc = parse(html)
    first = sectors(doc).first
    text = layer(doc, 2000).at_css("> text")

    assert_equal "5", first["stroke-width"]
    assert_equal "M 236,100\n    A 76,76,0,\n    0,0,\n    137.7455,27.3313\n  L 142.4306,42.63\n            A 60,60,0,\n            0,1,\n            220,100 Z", first["d"]
    assert_equal [ "recharts-text recharts-label", "middle", "160", "100", "#808080", "5" ], values(text, "class", "text-anchor", "x", "y", "fill", "offset")
    assert_equal [ "0.355em", "Visitors" ], [ text.at_css("tspan")["dy"], text.text ]
    assert_nil text["width"]
  end

  test "a label list writes the value of a key on every sector, in the fill of the sector unless the list has one" do
    html = render_pie { |pie| pie.label_list(data_key: :browser, class: "fill-background", stroke: "none", font_size: 12) }
    texts = layer(parse(html), 2000).css("> g.recharts-label-list > text")

    assert_equal %w[chrome safari firefox edge other], texts.map(&:text)
    assert_equal [ "recharts-text fill-background", "var(--color-chrome)", "none", "12", "middle" ],
                 values(texts.first, "class", "fill", "stroke", "font-size", "text-anchor")
    assert_in_delta 182.596, texts.first["x"].to_f, 0.001
    assert_in_delta 69.448, texts.first["y"].to_f, 0.001
  end

  test "label: true writes the values beside the sectors, with a line to each, past the rim" do
    doc = parse(render_pie(label: true))
    group = layer(doc, 2000).css("> g.recharts-layer")

    assert_equal 5, group.size
    assert_equal 1, layer(doc, 100).css("g.recharts-pie-labels").size
    line, text = group.first.element_children

    assert_equal [ "recharts-curve recharts-pie-label-line", "none", "var(--color-chrome)", "chrome" ], values(line, "class", "fill", "stroke", "name")
    assert_equal "M205.192,38.896L217.085,22.816", line["d"]
    assert_equal [ "recharts-text recharts-pie-label-text", "start", "none", "middle" ], values(text, "class", "text-anchor", "stroke", "alignment-baseline")
    assert_equal %w[0em 275], [ text.at_css("tspan")["dy"], text.text ]
    assert_equal "end", group[1].at_css("text")["text-anchor"]
  end

  test "label: takes offset_radius and the attributes of the text, label_line: false and a Hash style the line" do
    doc = parse(render_pie(label: { offset_radius: 30, fill: "red" }, label_line: { stroke: "blue", class: "ln" }))
    first = layer(doc, 2000).at_css("> g.recharts-layer")
    line, text = first.element_children

    assert_equal [ "blue", "recharts-curve recharts-pie-label-line ln" ], values(line, "stroke", "class")
    assert_equal "M205.192,38.896L223.031,14.776", line["d"]
    assert_equal [ "red", "recharts-text recharts-pie-label-text" ], values(text, "fill", "class")
    bare = layer(parse(render_pie(label: true, label_line: false)), 2000).css("> g.recharts-layer")

    assert_equal(5, bare.count { |group| group.at_css("path").nil? })
  end

  test "a hidden pie, or one with nothing to show, is the bare group written in place, right after the clip path" do
    [ render_pie(hide: true), render_pie(data: [ { browser: "a", visitors: 0 } ]) ].each do |html|
      surface = parse(html).at_css("svg")
      names = surface.element_children.map { |node| node["class"] || node.name }

      assert_equal [ "defs", "recharts-layer recharts-pie" ], names[4, 2]
      assert_equal "recharts-zIndex-layer_100", names[6]
      assert_empty surface.at_css("> g.recharts-pie").children
    end
  end

  test "a pie with no data of its own shows the data of the chart" do
    html = render_chart(Chadcn::Chart::PieChart, container: { config: BROWSER_CONFIG }, data: BROWSERS) { |chart| chart.pie(data_key: :visitors, name_key: :browser) }

    assert_equal 5, sectors(parse(html)).size
  end

  test "start and end angle run the pie clockwise, a padding angle and a corner radius round the sectors" do
    clockwise = sectors(parse(render_pie(start_angle: 90, end_angle: -270))).first
    rounded = sectors(parse(render_pie(padding_angle: 5, corner_radius: 6, min_angle: 10, inner_radius: 30, outer_radius: 90))).first

    assert_match(/\AM 160,24\n/, clockwise["d"])
    assert_match(/A6,6,0,0,0,/, rounded["d"])
  end

  test "a cell styles the sector at its index, its class replacing the pie's" do
    html = render_pie(class: "pcls", stroke: "red", stroke_width: 2) { |pie| pie.cell(fill: "blue", class: "ccls") }
    doc = parse(html)
    paths = sectors(doc)

    assert_equal [ "recharts-sector ccls", "blue", "red", "2" ], values(paths[0], "class", "fill", "stroke", "stroke-width")
    assert_equal [ "recharts-sector pcls", "var(--color-safari)" ], values(paths[1], "class", "fill")
    assert_equal %w[recharts-layer recharts-pie pcls], layer(doc, 100).at_css("> g.recharts-pie")["class"].split
  end

  test "text from the data row is escaped in the attributes and in the labels" do
    rows = [ { browser: "<b>x</b>", visitors: 5, fill: "\"><script>" }, { browser: "y", visitors: 5 } ]
    html = render_chart(Chadcn::Chart::PieChart, container: { config: BROWSER_CONFIG }, data: []) do |chart|
      chart.pie(data: rows, data_key: :visitors, name_key: :browser, label: true)
    end

    doc = parse(html)

    assert_empty doc.css("script, b")
    assert_equal [ "<b>x</b>", "\"><script>" ], values(sectors(doc).first, "name", "fill")
    assert_includes html, "fill=\"&quot;>"
  end

  test "ids are unique per chart: the container id, or a number of the render" do
    assert_equal "chart-t-clip", parse(render_pie).at_css("clipPath")["id"]
    assert_equal "chart-1-clip", parse(render_bare_chart(Chadcn::Chart::PieChart, data: BROWSERS) { |chart| chart.pie(data_key: :visitors) }).at_css("clipPath")["id"]
  end

  test "class and style go on the wrapper, role, tab_index and the other attributes on the svg" do
    chart = { class: "mine", style: "color: red;", role: "img", tab_index: 3, id: "pie-1", title: "Browsers", desc: "Share of visitors" }
    doc = parse(render_pie(chart: chart))
    wrapper = doc.at_css(".recharts-wrapper")
    surface = wrapper.at_css("> svg")

    assert_includes wrapper["class"], "mine"
    assert_match(/width: 320px; height: 200px; color: red;\z/, wrapper["style"])
    assert_equal %w[img 3 pie-1], values(surface, "role", "tabindex", "id")
    assert_equal [ "Browsers", "Share of visitors" ], [ surface.at_css("> title").text, surface.at_css("> desc").text ]
    assert_nil parse(render_pie(chart: { accessibility_layer: false })).at_css("svg")["role"]
  end

  test "the center of the chart is written on the svg" do
    surface = parse(render_pie(chart: { cx: 100, cy: "40%" })).at_css("svg")

    assert_equal %w[100 40%], values(surface, "cx", "cy")
  end

  test "refuses what is not a pie chart's: a radar, an axis, a bad data, margin, angle or share" do
    pie_chart = Chadcn::Chart::PieChart
    assert_raises(ArgumentError) { render_chart(pie_chart, data: [], &:polar_angle_axis) }
    assert_raises(ArgumentError) { pie_chart.new(data: "rows") }
    assert_raises(ArgumentError) { pie_chart.new(margin: 5) }
    assert_raises(ArgumentError) { pie_chart.new(start_angle: "0") }
    assert_raises(ArgumentError) { pie_chart.new(end_angle: Float::NAN) }
    assert_equal "cx: must be a number or a percent such as \"50%\" (got \"left\")", assert_raises(ArgumentError) { pie_chart.new(cx: "left") }.message
  end

  test "a second chart in a container is refused" do
    container = Chadcn::Chart::Container.new(config: BROWSER_CONFIG, id: "t")
    html = Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render(container) do
          render(Chadcn::Chart::PieChart.new) { |chart| chart.pie(data: BROWSERS, data_key: :visitors) }
          render(Chadcn::Chart::PieChart.new) { |chart| chart.pie(data: BROWSERS, data_key: :visitors) }
        end
      end
    end

    assert_raises(ArgumentError) { html.new.call }
  end
end

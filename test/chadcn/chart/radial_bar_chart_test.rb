# frozen_string_literal: true

require_relative "polar/polar_helper"

class Chadcn::Chart::RadialBarChartTest < Chadcn::TestCase
  include PolarHelper

  BAR_GROUPS = [ "recharts-layer recharts-radial-bar-background", "recharts-layer recharts-radial-bar-sectors" ].freeze
  FIRST = "M 213.6667,100\n    A 53.6667,53.6667,0,\n    1,0,\n    213.6667,100.0009\n  L 192.6667,100.0006\n            A 32.6667,32.6667,0,\n            1,1,\n            192.6667,100 Z"

  def bars(**props)
    render_radial_bar(chart: { outer_radius: 110 }.merge(props)) do |chart|
      chart.radial_bar(data_key: :visitors, background: true)
    end
  end

  test "an arc per row, one ring per category: the longest turns the whole circle, the others the share of their value" do
    doc = parse(bars)
    paths = arcs(doc)

    assert_equal 3, paths.size
    assert_equal FIRST, paths.first["d"]
    assert_equal [ "recharts-sector recharts-radial-bar-sector undefined", "var(--color-chrome)", "160", "100" ],
                 values(paths.first, "class", "fill", "cx", "cy")
    assert_equal "M 240.3333,100\n    A 80.3333,80.3333,0,\n    1,0,\n    148.5674,179.5157\n  L 151.556,158.7294\n            A 59.3333,59.3333,0,\n            1,1,\n            219.3333,100 Z", paths[1]["d"]
  end

  test "the groups are recharts': the area class, the empty background group, the sectors group with a shape group per arc" do
    group = layer(parse(bars), 300).at_css("> g.recharts-area")

    assert_equal %w[recharts-layer recharts-area], group["class"].split
    assert_equal(BAR_GROUPS, group.element_children.map { |node| node["class"] })
    assert_empty group.at_css("> g.recharts-radial-bar-background").children
    assert_equal 3, group.css("> g.recharts-radial-bar-sectors > g.recharts-shape > path").size
  end

  test "the background arcs, behind, span the whole angle in #eee with recharts' undefined class" do
    backgrounds = layer(parse(bars), -50).css("> g.recharts-shape > path")

    assert_equal 3, backgrounds.size
    assert_equal [ "recharts-sector recharts-radial-bar-background-sector undefined", "#eee" ], values(backgrounds.first, "class", "fill")
    assert_equal FIRST, backgrounds.first["d"]
    assert_equal "M 240.3333,100", backgrounds[1]["d"].split("\n").first
  end

  test "a background Hash gives the attributes and the class of the arcs behind" do
    html = render_radial_bar do |chart|
      chart.radial_bar(data_key: :visitors, background: { fill: "red", class: "bg", stroke: "blue" })
    end
    background = layer(parse(html), -50).at_css("path")

    assert_equal [ "recharts-sector recharts-radial-bar-background-sector bg", "red", "blue" ], values(background, "class", "fill", "stroke")
  end

  test "stacked bars ride on each other; what falls outside the domain of the angle axis is cut off" do
    rows = [ { month: "january", desktop: 1260, mobile: 570 } ]
    html = render_chart(Chadcn::Chart::RadialBarChart, data: rows, end_angle: 180, inner_radius: 80, outer_radius: 130) do |chart|
      chart.radial_bar(data_key: :desktop, stack_id: "a", corner_radius: 5, fill: "var(--color-desktop)", class: "stroke-transparent stroke-2")
      chart.radial_bar(data_key: :mobile, stack_id: "a", corner_radius: 5, fill: "var(--color-mobile)", class: "stroke-transparent stroke-2")
    end
    doc = parse(html)
    groups = layer(doc, 300).css("> g.recharts-area")

    assert_equal 2, groups.size
    assert_equal "recharts-layer recharts-area stroke-transparent stroke-2", groups.first["class"]
    assert_equal "M 279.8958,100\n    A5,5,0,0,0,284.8914,94.7917\n    A125,125,0,0,0,35.1086,94.7917\n    A5,5,0,0,0,40.1042,100\n  L70.139,100\n    A5,5,0,0,0,75.1313,95.2778\n    A85,85,0,0,1,244.8687,95.2778\n    A5,5,0,0,0,249.861,100Z".gsub(/\s+/, " "), arcs(doc).first["d"].gsub(/\s+/, " ")
    assert_empty groups.last.css("path")
    assert_equal 1, groups.last.css("g.recharts-shape").size
  end

  test "two bars without a stack id share the ring, side by side" do
    html = render_radial_bar(chart: { data: [ { browser: "a", visitors: 10, mobile: 5 }, { browser: "b", visitors: 20, mobile: 8 } ] }) do |chart|
      chart.radial_bar(data_key: :visitors, fill: "red")
      chart.radial_bar(data_key: :mobile, fill: "blue")
    end
    doc = parse(html)

    assert_equal %w[red blue], [ arcs(doc, 0).first["fill"], arcs(doc, 1).first["fill"] ]
    refute_equal arcs(doc, 0).first["d"], arcs(doc, 1).first["d"]
  end

  test "a label list follows the arc of the bar with a text path" do
    html = render_radial_bar do |chart|
      chart.radial_bar(data_key: :visitors) { |bar| bar.label_list(position: :inside_start, data_key: :browser, class: "fill-white capitalize", font_size: 11) }
    end
    label = layer(parse(html), 2000).at_css("> g.recharts-label-list > text")

    assert_equal [ "recharts-radial-bar-label fill-white capitalize", "var(--color-chrome)", "11", "central" ],
                 values(label, "class", "fill", "font-size", "dominant-baseline")
    assert_equal "chrome", label.at_css("textPath").text
    assert_equal "##{label.at_css('defs path')['id']}", label.at_css("textPath")["xlink:href"]
    assert_equal %w[chrome safari firefox], layer(parse(html), 2000).css("textPath").map(&:text)
  end

  test "the polar grid of circles follows the rings of the categories when it has no radial lines" do
    html = render_radial_bar do |chart|
      chart.polar_grid(grid_type: :circle, radial_lines: false)
      chart.radial_bar(data_key: :visitors)
    end
    group = layer(parse(html), -100).at_css("> g.recharts-polar-grid")

    assert_equal(%w[41.666666666666664 65 88.33333333333333], group.css("circle").map { |circle| circle["r"] })
    assert_nil group.at_css("g.recharts-polar-grid-angle")
  end

  test "a cell styles the arc at its index, a minimum point size lengthens a short arc, a negative value turns the other way" do
    html = render_radial_bar do |chart|
      chart.radial_bar(data_key: :visitors, min_point_size: 40) { |bar| bar.cell(fill: "blue", class: "ccls") }
    end
    rows = [ { browser: "a", visitors: 1 }, { browser: "b", visitors: 100 } ]
    short = parse(render_radial_bar(chart: { data: rows }) { |chart| chart.radial_bar(data_key: :visitors, min_point_size: 40) })

    assert_equal [ "recharts-sector recharts-radial-bar-sector ccls", "blue" ], values(arcs(parse(html)).first, "class", "fill")
    assert_equal 2, arcs(short).size
  end

  test "corner radius rounds the arcs, a text keeps its integer part" do
    rounded = parse(render_radial_bar { |chart| chart.radial_bar(data_key: :visitors, corner_radius: "5px") })

    assert_match(/A5,5,0,0,0,/, arcs(rounded)[1]["d"])
  end

  test "the legend lists the rows of the chart in their fill" do
    html = render_radial_bar do |chart|
      chart.legend(content: Chadcn::Chart::Legend::Content.new(name_key: :browser))
      chart.radial_bar(data_key: :visitors)
    end
    items = parse(html).css(".recharts-legend-wrapper > div > div")

    assert_equal(%w[Chrome Safari Firefox], items.map { |item| item.text.strip })
    assert_includes items.first.at_css("div")["style"], "var(--color-chrome)"
  end

  test "no data is the empty groups; a hidden bar draws nothing" do
    empty = parse(render_radial_bar(chart: { data: [] }) { |chart| chart.radial_bar(data_key: :visitors, background: true) })
    hidden = parse(render_radial_bar { |chart| chart.radial_bar(data_key: :visitors, hide: true) })

    assert_equal(BAR_GROUPS, layer(empty, 300).at_css("> g").element_children.map { |node| node["class"] })
    assert_empty layer(hidden, 300).children
  end

  test "the angle axis and the radius axis can be declared; the angle axis is a number axis here" do
    html = render_radial_bar do |chart|
      chart.polar_angle_axis(type: :number, domain: [ 0, 300 ])
      chart.polar_radius_axis(data_key: :browser, angle: 90, type: :category)
      chart.radial_bar(data_key: :visitors)
    end
    doc = parse(html)

    assert_equal "recharts-layer recharts-polar-angle-axis angleAxis", layer(doc, 500).at_css("> g")["class"]
    assert_equal %w[chrome safari firefox], layer(doc, 500).css("g.recharts-polar-radius-axis text").map(&:text)
  end

  test "refuses a pie, a radar and a bad option" do
    assert_raises(ArgumentError) { render_radial_bar { |chart| chart.radar(data_key: :visitors) } }
    assert_raises(ArgumentError) { Chadcn::Chart::RadialBarChart.new(end_angle: nil) }
  end
end

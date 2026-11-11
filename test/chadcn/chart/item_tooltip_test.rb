# frozen_string_literal: true

require_relative "cartesian/chart_helper"
require_relative "polar/polar_helper"

# `Tooltip shared: false` on a BarChart and a RadialBarChart: recharts' item tooltip (dev/port/specs/chart.md, "Tooltip", item #109).
# recharts activates the bar or sector under the pointer (context/tooltipContext.js) and shows that series alone at that row; the server
# writes one template per series and row, and tags every item shape so chadcn--chart knows which one the pointer is over.
class Chadcn::Chart::ItemTooltipTest < Chadcn::TestCase
  include ChartHelper
  include PolarHelper

  CONTENT = Chadcn::Chart::Tooltip::Content.new
  TEMPLATE = "template[data-chadcn--chart-target='tooltipTemplate']"
  ITEM = "[data-chadcn--chart-target='tooltipItem']"

  def bar_html(tooltip = {})
    render_chart do |chart|
      chart.x_axis(data_key: :month)
      chart.bar(data_key: :desktop)
      chart.bar(data_key: :mobile)
      chart.tooltip(shared: false, content: CONTENT, **tooltip)
    end
  end

  def radial_item_html(tooltip = {})
    render_radial_bar do |chart|
      chart.tooltip(shared: false, content: CONTENT, **tooltip)
      chart.radial_bar(data_key: :visitors)
    end
  end

  def chart_node(doc) = doc.at_css("div[data-slot='chart']")

  def value(doc, name) = chart_node(doc)["data-chadcn--chart-#{name}-value"]

  def templates(doc) = doc.css(TEMPLATE)

  def template(doc, series, index) = templates(doc).find { |node| node["data-series"] == series.to_s && node["data-index"] == index.to_s }

  test "a BarChart with shared: false writes one template per bar series and row, each with that series alone" do
    doc = parse(bar_html)

    assert_equal "item", value(doc, "tooltip-event-type")
    assert_equal ROWS.length * 2, templates(doc).length
    payload = JSON.parse(template(doc, 1, 3)["data-payload"])

    assert_equal([ { "name" => "mobile", "dataKey" => "mobile", "value" => ROWS[3][:mobile] } ], payload.map { |item| item.slice("name", "dataKey", "value") })
  end

  test "an item template has no label, no cursor and no active dots (component/Cursor.js:60 draws none for item tooltips)" do
    node = template(parse(bar_html), 0, 1)

    assert_nil node["data-label"]
    assert_nil node["data-cursor"]
    assert_equal "[]", node["data-active-dots"]
  end

  test "an item template anchors at the center of its bar (the bar's tooltipPosition) and keeps the axis anchor for the keyboard" do
    doc = parse(bar_html)
    node = template(doc, 1, 2)
    path = bars(doc, 1)[2]
    item = JSON.parse(node["data-item-coordinate"])

    assert_in_delta number(path, "x") + (number(path, "width") / 2), item["x"], 1e-3
    assert_in_delta number(path, "y") + (number(path, "height") / 2), item["y"], 1e-3
    tick = JSON.parse(value(doc, "ticks"))[2]
    anchor = JSON.parse(node["data-coordinate"])

    assert_in_delta tick["coordinate"], anchor["x"], 1e-4
    assert_in_delta 102.5, anchor["y"], 1e-9, "combineCoordinateForDefaultIndex: (offset.top + chart height) / 2"
  end

  test "every bar rectangle is a tooltip item tagged with its series and its position" do
    doc = parse(bar_html)
    items = doc.css("g.recharts-bar-rectangle#{ITEM}")

    assert_equal ROWS.length * 2, items.length
    assert_equal(%w[0 0], [ items.first["data-chadcn--chart-series"], items.first["data-chadcn--chart-index"] ])
    assert_equal(%w[1 5], [ items.last["data-chadcn--chart-series"], items.last["data-chadcn--chart-index"] ])
  end

  test "an item bar chart publishes its ticks (the keyboard steps through them) and starts with no pointer series" do
    doc = parse(bar_html)

    assert_equal((0...ROWS.length).to_a, JSON.parse(value(doc, "ticks")).map { |tick| tick["index"] })
    assert_equal "-1", value(doc, "pointer-series")
  end

  test "default_index on an item BarChart draws the first series at that row, visible, with no cursor" do
    doc = parse(bar_html(default_index: 1))
    wrapper = doc.at_css(".recharts-tooltip-wrapper")

    assert_equal "1", value(doc, "default-index")
    assert_includes wrapper["style"], "visibility: visible"
    assert_includes wrapper.text, ROWS[1][:desktop].to_s
    refute_includes wrapper.text, ROWS[1][:mobile].to_s
    assert_nil doc.at_css("[data-chadcn--chart-target='cursor']")
  end

  test "an axis BarChart tags no item and has no item templates" do
    doc = parse(render_chart do |chart|
      chart.x_axis(data_key: :month)
      chart.bar(data_key: :desktop)
      chart.tooltip(content: CONTENT)
    end)

    assert_empty doc.css(ITEM)
    assert_nil templates(doc).first["data-series"]
  end

  test "a RadialBarChart with shared: false writes a template per series and row with no item coordinate, and tags every sector" do
    doc = parse(radial_item_html)

    assert_equal "item", value(doc, "tooltip-event-type")
    assert_equal 3, templates(doc).length
    assert(templates(doc).all? { |node| node["data-item-coordinate"].nil? }, "a radial bar sector has no tooltipPosition in recharts")
    assert_equal 3, doc.css("path.recharts-radial-bar-sector#{ITEM}").length
    assert_empty doc.css("path.recharts-radial-bar-background-sector#{ITEM}")
  end

  test "a RadialBarChart with shared: false hears the pointer on its wrapper" do
    action = parse(radial_item_html).at_css(".recharts-wrapper")["data-action"]

    assert_includes action, "pointermove->chadcn--chart#move"
    assert_includes action, "pointerleave->chadcn--chart#leave"
    assert_includes action, "click->chadcn--chart#click"
    assert_includes action, "keydown@document->chadcn--chart#dismiss"
    refute_includes action, "focusin", "a polar chart has no keyboard layer yet (item #110)"
  end

  test "default_index on an item RadialBarChart draws the first series at that row" do
    doc = parse(radial_item_html(default_index: 1))
    wrapper = doc.at_css(".recharts-tooltip-wrapper")

    assert_includes wrapper["style"], "visibility: visible"
    assert_includes wrapper.text, BROWSERS[1][:visitors].to_s
  end

  test "a pie stays an inert item tooltip: its sectors are not tagged" do
    doc = parse(render_pie(around: ->(chart) { chart.tooltip(content: CONTENT) }))

    assert_empty doc.css(ITEM)
  end
end

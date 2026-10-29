# frozen_string_literal: true

require_relative "polar_helper"

class Chadcn::Chart::Polar::OverlaysTest < Chadcn::TestCase
  include PolarHelper

  def legend_items(html) = parse(html).css(".recharts-legend-wrapper > div > div")

  test "a pie legends its sectors by name, sorted, in the color of the row" do
    html = render_pie(around: ->(chart) { chart.legend(content: Chadcn::Chart::Legend::Content.new(name_key: :browser)) })
    items = legend_items(html)

    assert_equal(%w[Chrome Edge Firefox Other Safari], items.map { |item| item.text.strip })
    assert_includes items.first.at_css("div")["style"], "var(--color-chrome)"
  end

  test "a pie legend takes the cell's fill before the row's, and the pie's before nothing" do
    rows = [ { browser: "chrome", visitors: 3 }, { browser: "safari", visitors: 2, fill: "green" } ]
    html = render_chart(Chadcn::Chart::PieChart, container: { config: BROWSER_CONFIG }, data: []) do |chart|
      chart.legend(content: Chadcn::Chart::Legend::Content.new(name_key: :browser))
      chart.pie(data: rows, data_key: :visitors, name_key: :browser, fill: "gray") { |pie| pie.cell(fill: "red") }
    end
    styles = legend_items(html).map { |item| item.at_css("div")["style"] }

    assert_includes styles[0], "red"
    assert_includes styles[1], "green"
  end

  test "a radar legends itself: its name, or its data key, in its stroke or its fill" do
    html = render_radar do |chart|
      chart.legend(content: Chadcn::Chart::Legend::Content.new)
      chart.radar(data_key: :desktop, fill: "var(--color-desktop)", stroke: "none")
    end
    item = legend_items(html).first

    assert_equal "Desktop", item.text.strip
    assert_includes item.at_css("div")["style"], "var(--color-desktop)"
  end

  test "a legend placed on the top, with a width, takes the room from its side, and the wrapper follows" do
    html = render_pie(around: ->(chart) { chart.legend(vertical_align: :top, content: Chadcn::Chart::Legend::Content.new(name_key: :browser)) })
    doc = parse(html)

    assert_includes doc.at_css(".recharts-legend-wrapper")["style"], "top: 5px"
    assert_equal(%w[33 162], doc.at_css("clipPath rect").then { |rect| [ rect["y"], rect["height"] ] })
  end

  test "the tooltip wrapper is hidden and empty at rest, visible with the content of default_index" do
    content = Chadcn::Chart::Tooltip::Content.new(hide_label: true)
    rest = parse(render_pie(around: ->(chart) { chart.tooltip(content: content) }))
    shown = parse(render_pie(around: ->(chart) { chart.tooltip(default_index: 1, content: content) }))

    assert_includes rest.at_css(".recharts-tooltip-wrapper")["style"], "visibility: hidden"
    assert_empty rest.at_css(".recharts-tooltip-wrapper").children
    assert_includes shown.at_css(".recharts-tooltip-wrapper")["style"], "visibility: visible"
    assert_includes shown.at_css(".recharts-tooltip-wrapper").text, "Safari"
  end

  test "an inert template per sector follows the shell, with its index, its coordinate and no cursor" do
    html = render_pie(around: ->(chart) { chart.tooltip(cursor: false, content: Chadcn::Chart::Tooltip::Content.new(hide_label: true)) })
    templates = parse(html).css("div[data-slot=chart] > template[data-chadcn--chart-target=tooltipTemplate]")

    assert_equal(%w[0 1 2 3 4], templates.map { |template| template["data-index"] })
    assert_equal "", templates.first["data-label"]
    assert_nil templates.first["data-cursor"]
    assert_equal "[]", templates.first["data-active-dots"]
    assert_equal %w[x y], JSON.parse(templates.first["data-coordinate"]).keys
  end
end

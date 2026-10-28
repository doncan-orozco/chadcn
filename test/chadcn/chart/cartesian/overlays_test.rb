# frozen_string_literal: true

require_relative "chart_helper"

class Chadcn::Chart::Cartesian::OverlaysTest < Chadcn::TestCase
  include ChartHelper

  LegendContent = Chadcn::Chart::Legend::Content

  def render_legend(legend: {}, content: LegendContent.new, **props, &block)
    block ||= lambda { |chart|
      chart.bar(data_key: :desktop, fill: "var(--color-desktop)")
      chart.bar(data_key: :mobile, fill: "var(--color-mobile)")
    }
    render_chart(Chadcn::Chart::BarChart, **props) do |chart|
      chart.legend(content: content, **legend)
      block.call(chart)
    end
  end

  def wrapper(html) = parse(html).at_css(".recharts-legend-wrapper")

  def labels(html) = wrapper(html).css("div.flex.items-center.gap-1\\.5").map(&:text)

  test "the legend wrapper sits in front of the svg, pinned to the bottom of the margin with the width of the plot" do
    html = render_legend
    plot = parse(html).at_css(".recharts-wrapper")

    assert_equal %w[div svg], plot.element_children.map(&:name)
    assert_equal "position: absolute; width: 310px; height: auto; left: 5px; bottom: 5px;", wrapper(html)["style"]
    assert_equal %w[Desktop Mobile], labels(html)
  end

  test "the legend takes its room from the plot and sits on the side vertical_align names" do
    top = wrapper(render_legend(legend: { vertical_align: :top }))
    plain = parse(render_chart { |chart| chart.bar(data_key: :desktop) })
    legend_plot = parse(render_legend).at_css("clipPath rect")

    assert_equal "position: absolute; width: 310px; height: auto; left: 5px; top: 5px;", top["style"]
    assert_includes top.at_css("div").[]("class"), "pb-3"
    assert_in_delta(162.0, legend_plot["height"].to_f)
    assert_in_delta(190.0, plain.at_css("clipPath rect")["height"].to_f)
  end

  test "align, layout, width, height and wrapper_style place the wrapper like Legend.js" do
    right = wrapper(render_legend(legend: { align: :right, width: 100, height: 30 }))
    vertical = wrapper(render_legend(legend: { layout: :vertical, align: :center, width: 100 }))
    middle = wrapper(render_legend(legend: { vertical_align: :middle, wrapper_style: { left: "9px" } }))

    assert_equal "position: absolute; width: 100px; height: 30px; right: 5px; bottom: 5px;", right["style"]
    assert_equal "position: absolute; width: 100px; height: auto; left: 110px; bottom: 5px;", vertical["style"]
    assert_equal "position: absolute; width: 310px; height: auto; left: 9px; top: 86px;", middle["style"]
  end

  test "item_sorter sorts by value, nil keeps the series order, payload_uniq_by keeps the first of equal values" do
    sorted = render_legend do |chart|
      chart.bar(data_key: :mobile)
      chart.bar(data_key: :desktop)
    end
    kept = render_legend(legend: { item_sorter: nil }) do |chart|
      chart.bar(data_key: :mobile)
      chart.bar(data_key: :desktop)
    end
    unique = render_legend(legend: { payload_uniq_by: true }) do |chart|
      chart.bar(data_key: :desktop, name: "Same")
      chart.bar(data_key: :mobile, name: "Same")
    end

    assert_equal %w[Desktop Mobile], labels(sorted)
    assert_equal %w[Mobile Desktop], labels(kept)
    assert_equal 1, wrapper(unique).css("div.h-2").size
  end

  test "the payload carries the color of the series, a hidden series stays, a legend_type none series is dropped by the content" do
    html = render_legend do |chart|
      chart.bar(data_key: :desktop, fill: "red")
      chart.bar(data_key: :mobile, fill: "blue", hide: true)
      chart.bar(data_key: :desktop, name: "none", fill: "green", legend_type: :none)
    end
    swatches = wrapper(html).css("div.h-2").map { |node| node["style"] }

    assert_equal [ "background-color: red;", "background-color: blue;" ], swatches
  end

  test "a line uses its stroke and an area its stroke, else its fill" do
    html = render_chart(Chadcn::Chart::AreaChart) do |chart|
      chart.legend(content: LegendContent.new)
      chart.area(data_key: :desktop, stroke: "none", fill: "orange")
      chart.area(data_key: :mobile, stroke: "purple", fill: "pink")
    end

    assert_equal([ "background-color: orange;", "background-color: purple;" ], wrapper(html).css("div.h-2").map { |node| node["style"] })
  end

  test "a legend without content is an empty wrapper, and one in a chart with no container refuses its content" do
    assert_empty wrapper(render_legend(content: nil)).children
    assert_raises(ArgumentError) do
      render_bare_chart do |chart|
        chart.legend(content: LegendContent.new)
        chart.bar(data_key: :desktop)
      end
    end
  end

  test "a middle legend with a numeric height is centered by that height, the one Layout reserves" do
    middle = wrapper(render_legend(legend: { vertical_align: :middle, height: 40 }))

    assert_includes middle["style"], "top: 80px;"
  end

  test "wrapper_style keys are CSS names: zIndex and z_index are z-index, unitless; custom properties are kept" do
    [ { zIndex: 3 }, { z_index: 3 } ].each do |style|
      assert_includes wrapper(render_legend(legend: { wrapper_style: style }))["style"], "z-index: 3;"
    end
    custom = wrapper(render_legend(legend: { wrapper_style: { "--gap": 2, backgroundColor: "red" } }))["style"]

    assert_includes custom, "--gap: 2px;"
    assert_includes custom, "background-color: red;"
  end

  test "a String wrapper_style cannot leave the style attribute, on the legend or the tooltip wrapper" do
    hostile = 'color: red" onmouseover="x'
    legend = wrapper(render_legend(legend: { wrapper_style: hostile }))
    tooltip = parse(render_chart do |chart|
      chart.tooltip(content: Chadcn::Chart::Tooltip::Content.new, wrapper_style: hostile)
      chart.bar(data_key: :desktop)
    end).at_css(".recharts-tooltip-wrapper")

    [ legend, tooltip ].each do |node|
      assert_nil node["onmouseover"]
      assert_includes node["style"], "onmouseover"
    end
  end
end

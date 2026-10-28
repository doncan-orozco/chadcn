# frozen_string_literal: true

require_relative "chart_helper"

class Chadcn::Chart::Cartesian::RootTest < Chadcn::TestCase
  include ChartHelper

  test "the chart classes share the root and say which chart they are" do
    assert_equal [ :bar, :line, :area ], [ Chadcn::Chart::BarChart, Chadcn::Chart::LineChart, Chadcn::Chart::AreaChart ].map { |klass| klass::CHART_TYPE }
    assert(Chadcn::Chart::BarChart < Chadcn::Chart::Cartesian::Root)
  end

  test "the block receives the chart and its helpers" do
    yielded = nil
    render_chart { |chart| yielded = chart }

    assert_instance_of Chadcn::Chart::BarChart, yielded
    assert_respond_to yielded, :bar
    assert_respond_to yielded, :tooltip
  end

  test "the title and the description are escaped text of the svg" do
    doc = parse(render_chart(title: "Sales & more", desc: "a < b"))

    assert_equal "Sales & more", doc.at_css("svg > title").text
    assert_equal "a < b", doc.at_css("svg > desc").text
  end

  test "the layout can be given as a string and the margin as a Hash with string keys" do
    html = render_chart(layout: "vertical", margin: { "left" => 10 }) do |chart|
      chart.x_axis(type: :number)
      chart.y_axis(data_key: :month, type: :category)
      chart.bar(data_key: :desktop)
    end

    assert_equal "70", parse(html).at_css("clipPath rect")["x"]
  end

  test "ids are unique per chart: the container id, or a number of the render" do
    inside = parse(render_chart { |chart| chart.bar(data_key: :desktop) })
    bare = parse(render_bare_chart { |chart| chart.bar(data_key: :desktop) })

    assert_equal "chart-t-clip", inside.at_css("clipPath")["id"]
    assert_equal "chart-1-clip", bare.at_css("clipPath")["id"]
  end

  test "a tooltip or legend written in the chart is accepted and kept for the overlays" do
    html = render_chart do |chart|
      chart.tooltip(default_index: 1)
      chart.legend(vertical_align: :top)
      chart.bar(data_key: :desktop)
    end

    assert_equal 12, parse(html).css("svg > g").size
  end
end

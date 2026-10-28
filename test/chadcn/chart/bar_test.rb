# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::BarTest < Chadcn::TestCase
  include ChartHelper

  test "defaults equal recharts' and the options are frozen" do
    options = Chadcn::Chart::Bar.new(data_key: :desktop).options

    assert_equal [ 0, :rect, false, false, 0, 0 ], options.values_at(:min_point_size, :legend_type, :background, :hide, :x_axis_id, :y_axis_id)
    assert_nil options[:stack_id]
    assert_predicate options, :frozen?
  end

  test "data_key is required and options accept strings" do
    assert_raises(ArgumentError) { Chadcn::Chart::Bar.new }
    assert_equal :square, Chadcn::Chart::Bar.new(data_key: :a, legend_type: "square").options[:legend_type]
    assert_equal :none, Chadcn::Chart::Bar.new(data_key: :a, tooltip_type: "none").options[:tooltip_type]
  end

  test "invalid options raise" do
    assert_raises(ArgumentError) { Chadcn::Chart::Bar.new(data_key: :a, radius: [ 1, 2, 3, 4, 5 ]) }
    assert_raises(ArgumentError) { Chadcn::Chart::Bar.new(data_key: :a, radius: "4") }
    assert_raises(ArgumentError) { Chadcn::Chart::Bar.new(data_key: :a, legend_type: :banana) }
    assert_raises(ArgumentError) { Chadcn::Chart::Bar.new(data_key: :a, tooltip_type: :loud) }
    assert_raises(ArgumentError) { Chadcn::Chart::Bar.new(data_key: :a, active_bar: { fill: "red" }) }
  end

  test "the data key can be a callable that receives the row" do
    doc = parse(render_chart { |chart| chart.bar(data_key: ->(row) { row[:desktop] / 2 }) })

    assert_equal 6, doc.css("path.recharts-rectangle").size
  end

  test "name, stroke and attributes land on every rectangle, class and id on the group" do
    doc = parse(render_chart do |chart|
      chart.bar(data_key: :desktop, name: "Desk", stroke: "red", stroke_width: 2, class: "grp", id: "the-bar", data: { series: "d" })
    end)
    group = doc.at_css("g.recharts-bar")
    rect = group.at_css("path")

    assert_equal [ "recharts-layer recharts-bar grp", "the-bar" ], values(group, "class", "id")
    assert_equal %w[Desk red 2 d], values(rect, "name", "stroke", "stroke-width", "data-series")
    assert_nil rect["id"]
  end

  test "a data row's own fill overrides the bar's on its rectangle" do
    rows = [ { month: "A", desktop: 1, fill: "orange" }, { month: "B", desktop: 2 } ]
    first, second = bars(parse(render_chart(data: rows) { |chart| chart.bar(data_key: :desktop, fill: "green") }))

    assert_equal %w[orange green], [ first["fill"], second["fill"] ]
  end

  test "label: true draws a label list" do
    doc = parse(render_chart { |chart| chart.bar(data_key: :desktop, label: true) })

    assert_equal 6, layer(doc, 2000).css(".recharts-label-list text").size
  end
end

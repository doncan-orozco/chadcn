# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::LabelTest < Chadcn::TestCase
  include ChartHelper

  test "defaults equal recharts' Label" do
    options = Chadcn::Chart::Label.new(value: "x").options

    assert_equal [ "x", :middle, 5, 0 ], options.values_at(:value, :position, :offset, :angle)
  end

  test "draws its value around the plot and nothing without one" do
    with = parse(render_chart do |chart|
      chart.label(value: "Hello", position: :inside_top_left, offset: 10, fill: "red")
      chart.bar(data_key: :desktop)
    end)
    without = parse(render_chart do |chart|
      chart.label
      chart.bar(data_key: :desktop)
    end)
    text = layer(with, 2000).at_css("text.recharts-label")

    assert_equal %w[Hello red 15 15 start], [ text.text, text["fill"], text["x"], text["y"], text["text-anchor"] ]
    assert_nil layer(without, 2000).at_css("text")
  end

  test "a position outside the list raises" do
    assert_raises(ArgumentError) { Chadcn::Chart::Label.new(position: :nowhere) }
  end
end

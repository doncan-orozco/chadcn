# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::LabelListTest < Chadcn::TestCase
  include ChartHelper

  test "defaults equal recharts' Label: middle, offset 5" do
    options = Chadcn::Chart::LabelList.new.options

    assert_equal [ :middle, 5, 0 ], options.values_at(:position, :offset, :angle)
    assert_nil options[:data_key]
  end

  test "position accepts strings, snake_case names and a point" do
    assert_equal :inside_top, Chadcn::Chart::LabelList.new(position: "inside_top").options[:position]
    assert_equal({ x: 1, y: 2 }, Chadcn::Chart::LabelList.new(position: { x: 1, y: 2 }).options[:position])
    assert_raises(ArgumentError) { Chadcn::Chart::LabelList.new(position: :nowhere) }
  end

  test "data_key shows another column and the formatter shapes the text" do
    html = render_chart do |chart|
      chart.bar(data_key: :desktop) { |bar| bar.label_list(data_key: :month, position: :inside_bottom, formatter: { slice: [ 0, 1 ] }, fill: "white") }
    end
    texts = layer(parse(html), 2000).css(".recharts-label-list text")

    assert_equal %w[J F M A M J], texts.map(&:text)
    assert_equal "white", texts.first["fill"]
  end

  test "a label with no value is not drawn and a wide label is broken to the width of its bar" do
    rows = [ { month: "A", desktop: 5 }, { month: "B", desktop: nil }, { month: "C", desktop: 9 } ]
    wide = ->(_value) { "Alpha Beta Gamma Delta" }
    html = render_chart(data: rows) { |chart| chart.bar(data_key: :desktop) { |bar| bar.label_list(data_key: :month, formatter: wide) } }
    texts = layer(parse(html), 2000).css(".recharts-label-list text")

    assert_equal 2, texts.size
    assert_operator texts.first.css("tspan").size, :>, 1
  end

  test "the class replaces recharts-label, a text_anchor attribute wins over the position's" do
    html = render_chart { |chart| chart.bar(data_key: :desktop) { |bar| bar.label_list(class: "mine", text_anchor: "start") } }
    text = layer(parse(html), 2000).at_css("text")

    assert_equal [ "recharts-text mine", "start" ], values(text, "class", "text-anchor")
  end
end

# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::YAxisTest < Chadcn::TestCase
  include ChartHelper

  test "defaults equal recharts' yAxisDefaultProps: a number axis on the left with domain 0 to auto" do
    settings = Chadcn::Chart::YAxis.new.settings

    assert_equal [ :number, false, 60, :left, 5 ], settings.to_h.values_at(:type, :hide, :size, :orientation, :tick_count)
    assert_equal [ 0, "auto" ], settings.domain
    assert_equal({ top: 0, bottom: 0 }, settings.padding)
  end

  test "y_axis_id becomes the id and a right axis takes the room on the right" do
    html = render_chart do |chart|
      chart.y_axis(orientation: "right", y_axis_id: 0, tick_margin: 4)
      chart.bar(data_key: :desktop)
    end
    doc = parse(html)

    assert_equal "250", doc.at_css("clipPath rect")["width"]
    assert_equal "5", doc.at_css("clipPath rect")["x"]
    assert_equal "start", layer(doc, 2000).at_css("text")["text-anchor"]
  end

  test "an explicit domain, tick_count and allow_decimals shape the ticks" do
    html = render_chart(margin: { top: 5, bottom: 20 }) do |chart|
      chart.y_axis(domain: [ 0, 400 ], tick_count: 3, allow_decimals: false, tick_formatter: :locale)
      chart.bar(data_key: :desktop)
    end

    assert_equal %w[0 200 400], parse(html).css(".recharts-yAxis-tick-labels text").map(&:text)
  end

  test "invalid options raise" do
    assert_raises(ArgumentError) { Chadcn::Chart::YAxis.new(orientation: :top) }
    assert_raises(ArgumentError) { Chadcn::Chart::YAxis.new(domain: 5) }
  end

  test "a hidden axis takes no room and draws nothing; a second axis is drawn beside the first" do
    hidden = parse(render_chart do |chart|
      chart.y_axis(hide: true)
      chart.bar(data_key: :desktop)
    end)
    two = parse(render_chart do |chart|
      chart.y_axis
      chart.y_axis(y_axis_id: "b", width: 30)
      chart.bar(data_key: :desktop)
    end)

    assert_nil hidden.at_css(".recharts-yAxis")
    assert_equal "5", hidden.at_css("clipPath rect")["x"]
    assert_equal 2, two.css("g.recharts-yAxis").size
    assert_equal %w[30 60], two.css("g.recharts-yAxis line.recharts-cartesian-axis-line").map { |line| line["width"] }.sort
  end
end

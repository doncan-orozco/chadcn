# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::XAxisTest < Chadcn::TestCase
  include ChartHelper

  test "defaults equal recharts' xAxisDefaultProps, and a declared axis is shown" do
    settings = Chadcn::Chart::XAxis.new.settings

    assert_equal [ :category, false, 30, :bottom, 6, 2, 5, :preserve_end, 5 ],
                 settings.to_h.values_at(:type, :hide, :size, :orientation, :tick_size, :tick_margin, :tick_count, :interval, :min_tick_gap)
    assert_equal [ true, true, true, :auto, "#666", 0 ], settings.to_h.values_at(:tick, :tick_line, :axis_line, :nice_ticks, :stroke, :id)
    assert_equal({ left: 0, right: 0 }, settings.padding)
  end

  test "x_axis_id becomes the id and the keyword options accept strings" do
    settings = Chadcn::Chart::XAxis.new(x_axis_id: "a", orientation: "top", type: "number", nice_ticks: "none").settings

    assert_equal [ "a", :top, :number, :none ], settings.to_h.values_at(:id, :orientation, :type, :nice_ticks)
  end

  test "invalid options raise" do
    assert_raises(ArgumentError) { Chadcn::Chart::XAxis.new(orientation: :left) }
    assert_raises(ArgumentError) { Chadcn::Chart::XAxis.new(scale: :log) }
    assert_raises(ArgumentError) { Chadcn::Chart::XAxis.new(interval: -1) }
  end

  test "an auto type resolves by the layout of the chart" do
    horizontal = parse(render_chart do |chart|
      chart.x_axis(type: :auto, data_key: :month, tick_formatter: SLICE)
      chart.bar(data_key: :desktop)
    end)
    vertical = parse(render_chart(layout: :vertical) do |chart|
      chart.x_axis(type: :auto)
      chart.y_axis(type: :auto, data_key: :month, tick_formatter: SLICE)
      chart.bar(data_key: :desktop)
    end)

    assert_equal %w[Jan Feb Mar Apr May Jun], horizontal.css(".recharts-xAxis-tick-labels text").map(&:text)
    assert_equal %w[Jan Feb Mar Apr May Jun], vertical.css(".recharts-yAxis-tick-labels text").map(&:text)
  end

  test "reversed, interval and tick_count shape the labels" do
    reversed = parse(render_chart do |chart|
      chart.x_axis(data_key: :month, reversed: true, tick_formatter: SLICE)
      chart.bar(data_key: :desktop)
    end)
    skipping = parse(render_chart do |chart|
      chart.x_axis(data_key: :month, interval: 1, tick_formatter: SLICE)
      chart.bar(data_key: :desktop)
    end)

    labels = reversed.css(".recharts-xAxis-tick-labels text")

    assert_equal %w[Jan Feb Mar Apr May Jun], labels.map(&:text)
    assert_operator labels.first["x"].to_f, :>, labels.last["x"].to_f
    assert_equal %w[Jan Mar May], skipping.css(".recharts-xAxis-tick-labels text").map(&:text)
  end
end

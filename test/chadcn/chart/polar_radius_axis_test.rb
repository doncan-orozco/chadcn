# frozen_string_literal: true

require_relative "polar/polar_helper"

class Chadcn::Chart::PolarRadiusAxisTest < Chadcn::TestCase
  include PolarHelper

  def axis(**props)
    html = render_radar do |chart|
      chart.polar_angle_axis(data_key: :month)
      chart.polar_radius_axis(**props)
      chart.radar(data_key: :desktop)
    end
    layer(parse(html), 500).at_css("> g.recharts-polar-radius-axis")
  end

  test "defaults equal recharts' (polar/defaultPolarRadiusAxisProps.js)" do
    settings = Chadcn::Chart::PolarRadiusAxis.new.settings

    assert_equal [ :auto, 0, 5, :right, "#ccc" ], [ settings.type, settings.angle, settings.tick_count, settings.orientation, settings.stroke ]
    assert_equal [ false, true, true ], [ settings.allow_decimals, settings.tick, settings.axis_line ]
  end

  test "the ticks are nice numbers, the line runs from the first to the last, the labels hang right of the axis" do
    group = axis
    texts = group.css("text")

    assert_equal %w[0 80 160 240 320], texts.map(&:text)
    assert_equal %w[160 100 236 100], values(group.at_css("> line"), "x1", "y1", "x2", "y2")
    assert_equal [ "recharts-text recharts-polar-radius-axis-tick-value", "start", "none", "#ccc" ],
                 values(texts.first, "class", "text-anchor", "stroke", "fill")
  end

  test "the angle turns the axis and rotates the labels upright on it" do
    texts = axis(angle: 30).css("text")

    assert_equal "rotate(60, 160, 100)", texts.first["transform"]
    assert_equal %w[160 100], values(texts.first, "x", "y")
    assert_match(/\Arotate\(60, 2\d\d\.\d+, 6\d\.\d+\)\z/, texts.last["transform"])
  end

  test "left and middle orientations anchor the labels; tick false and axis_line false drop them" do
    assert_equal %w[end middle], [ axis(orientation: :left).css("text").first["text-anchor"], axis(orientation: "middle").css("text").first["text-anchor"] ]
    assert_empty axis(tick: false).css("text")
    assert_nil axis(axis_line: false).at_css("> line")
  end

  test "a domain, a tick count and a tick formatter shape the labels; the class replaces the class of the line" do
    group = axis(domain: [ 0, 400 ], tick_count: 3, tick_formatter: ->(value, index) { "#{index}:#{value.to_i}" }, class: "mine", axis_line: { stroke: "red" })

    assert_equal %w[0:0 1:200 2:400], group.css("text").map(&:text)
    assert_equal "mine", group.at_css("> line")["class"]
    assert_equal "red", group.at_css("> line")["stroke"]
    assert_equal "recharts-layer recharts-polar-radius-axis radiusAxis mine", group["class"]
  end

  test "a bad orientation or type raises, and a tick count of nothing draws no axis" do
    assert_raises(ArgumentError) { Chadcn::Chart::PolarRadiusAxis.new(orientation: :top) }
    assert_raises(ArgumentError) { Chadcn::Chart::PolarRadiusAxis.new(type: :log) }
    assert_nil(axis(tick_count: 0).then { |group| group&.at_css("text") })
  end
end

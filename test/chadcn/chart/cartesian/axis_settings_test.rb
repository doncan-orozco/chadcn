# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Cartesian::AxisSettingsTest < Chadcn::TestCase
  AxisSettings = Chadcn::Chart::Cartesian::AxisSettings

  def build(kind = :x, **changes)
    defaults = { data_key: nil, type: :category, hide: false, size: 30, orientation: :bottom, tick: true, tick_line: true, axis_line: true, tick_size: 6,
                 tick_margin: 2, tick_count: 5, tick_formatter: nil, interval: :preserve_end, min_tick_gap: 5, mirror: false, reversed: false, padding: nil,
                 domain: nil, allow_decimals: true, allow_duplicated_category: true, allow_data_overflow: false, include_hidden: false, nice_ticks: :auto,
                 angle: 0, unit: nil, ticks: nil, scale: :auto, stroke: "#666", axis_id: 0, name: nil, attrs: {} }
    AxisSettings.build(kind, **defaults.merge(changes))
  end

  test "an axis nobody declared is hidden, with recharts' implicit defaults" do
    x = AxisSettings.implicit(:x)
    y = AxisSettings.implicit(:y)

    assert x.hide
    assert_equal [ :category, :bottom, 30 ], [ x.type, x.orientation, x.size ]
    assert_equal [ :number, :left, 60 ], [ y.type, y.orientation, y.size ]
    assert_equal [ 0, "auto" ], y.domain_definition
    assert_equal 7, AxisSettings.implicit(:x, 7).id
  end

  test "string and symbol options are the same, an unknown one raises" do
    assert_equal :top, build(orientation: "top").orientation
    assert_equal :number, build(type: "number").type
    assert_equal :snap125, build(nice_ticks: "snap125").nice_ticks
    assert_equal :preserve_start, build(interval: "preserve_start").interval
    assert_equal 2, build(interval: 2).interval
    assert_raises(ArgumentError) { build(orientation: :left) }
    assert_raises(ArgumentError) { build(:y, orientation: :bottom) }
    assert_raises(ArgumentError) { build(type: :log) }
    assert_raises(ArgumentError) { build(scale: :log) }
    assert_raises(ArgumentError) { build(interval: :sometimes) }
    assert_raises(ArgumentError) { build(nice_ticks: :pretty) }
    assert_raises(ArgumentError) { build(domain: [ 0 ]) }
    assert_raises(ArgumentError) { build(padding: 5) }
  end

  test "a domain bound is normalized: auto, data_min, data_max and numbers" do
    settings = build(domain: [ :data_min, "dataMax" ])

    assert_equal %w[dataMin dataMax], settings.domain
    assert_equal [ 0, "auto" ], build(domain: nil).domain_definition
    assert build(domain: [ 0, :auto ]).auto_domain?
    assert_not build(domain: [ 0, 100 ]).auto_domain?
  end

  test "user ticks of a number axis define the domain" do
    assert_equal [ 10.0, 50.0 ], build(:y, type: :number, ticks: [ 10, "50", 30 ], orientation: :left).domain_definition
  end

  test "padding takes the sides of the kind, missing ones are 0" do
    assert_equal({ left: 3.0, right: 0 }, build(padding: { left: 3 }).padding.to_h { |side, value| [ side, value ] })
    assert_equal({ top: 0, bottom: 0 }, build(:y, orientation: :left, padding: nil).padding)
  end

  test "a tick formatter is resolved into a callable" do
    assert_equal "Jan", build(tick_formatter: { slice: [ 0, 3 ] }).tick_formatter.call("January", 0)
  end
end

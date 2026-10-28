# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Cartesian::TickLayoutTest < Chadcn::TestCase
  TickLayout = Chadcn::Chart::Cartesian::TickLayout
  VIEW = { x: 0.0, y: 0.0, width: 320.0, height: 200.0 }.freeze

  def ticks(coordinates, values = nil)
    coordinates.each_with_index.map do |coordinate, index|
      TickLayout::Tick.new(index: index, value: values ? values[index] : "T#{index}", coordinate: coordinate, offset: 0)
    end
  end

  def visible(list, **changes)
    settings = TickLayout::Settings.new(**{ orientation: :bottom, interval: :preserve_end, min_tick_gap: 5, formatter: nil, unit: nil, angle: 0,
                                            view_box: VIEW }.merge(changes))
    TickLayout.visible(list, settings, Chadcn::Chart::Cartesian::Text.new)
  end

  test "labels that fit are all kept" do
    assert_equal %w[T0 T1 T2], visible(ticks([ 50, 150, 250 ])).map(&:value)
    assert_empty visible([])
  end

  test "walking from the end, a label that would overlap the one after it is dropped" do
    kept = visible(ticks([ 100, 108, 200, 300 ], %w[AAAA BBBB CCCC DDDD]))

    assert_equal %w[BBBB CCCC DDDD], kept.map(&:value)
  end

  test "the last label is pulled back inside the chart by half its size" do
    kept = visible(ticks([ 100, 318 ], %w[A Wide]))

    assert_in_delta 305.6, kept.last.tick_coord, 0.0001
    assert_equal 100, kept.first.tick_coord
  end

  test "preserve_start keeps the first label and drops what follows it" do
    kept = visible(ticks([ 10, 14, 100 ], %w[AAAA BBBB CCCC]), interval: :preserve_start)

    assert_equal %w[AAAA CCCC], kept.map(&:value)
    assert_in_delta 14.4, kept.first.tick_coord, 0.0001
  end

  test "preserve_start_end keeps both ends" do
    kept = visible(ticks([ 10, 160, 312 ], %w[A B CCCCCC]), interval: :preserve_start_end)

    assert_equal %w[A B CCCCCC], kept.map(&:value)
  end

  test "a numeric interval keeps every n+1-th tick and measures nothing" do
    assert_equal %w[T0 T2 T4], visible(ticks([ 10, 20, 30, 40, 50 ]), interval: 1).map(&:value)
    assert_equal %w[T0 T1], visible(ticks([ 10, 20 ]), interval: 0).map(&:value)
  end

  test "equidistant intervals keep an even subset that fits" do
    list = ticks((0..9).map { |index| 10 + (index * 12) }, (1..10).map { |index| "Label #{index}" })
    start = visible(list, interval: :equidistant_preserve_start)
    finish = visible(list, interval: :equidistant_preserve_end)

    assert_equal 0, start.first.index
    assert_equal 9, finish.last.index
    assert_operator start.size, :<, list.size
    assert_equal 1, start.map(&:index).each_cons(2).map { |before, after| after - before }.uniq.size
    assert_equal 1, finish.map(&:index).each_cons(2).map { |before, after| after - before }.uniq.size
  end

  test "a vertical axis compares label heights" do
    kept = visible(ticks([ 10, 14, 100 ], %w[a b c]), orientation: :left)

    assert_equal %w[b c], kept.map(&:value)
  end

  test "a formatter and a unit change the width of a label" do
    wide = visible(ticks([ 150, 170 ], %w[a b]), formatter: ->(value, _index) { "#{value}-wide-label" })
    unit = visible(ticks([ 150, 170 ], %w[a b]), unit: "kilograms")

    assert_equal 1, wide.size
    assert_equal 1, unit.size
    assert_equal 2, visible(ticks([ 150, 170 ], %w[a b])).size
  end

  test "descending coordinates are walked the other way and keep their order" do
    assert_equal %w[T0 T1], visible(ticks([ 300, 100 ])).map(&:value)
  end

  test "an angle shortens the horizontal room a label takes" do
    straight = visible(ticks([ 100, 125 ], %w[AAAAAAAA BBBBBBBB]))
    turned = visible(ticks([ 100, 125 ], %w[AAAAAAAA BBBBBBBB]), angle: 90)

    assert_equal 1, straight.size
    assert_equal 2, turned.size
  end
end

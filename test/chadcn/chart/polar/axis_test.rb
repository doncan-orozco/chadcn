# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Polar::AxisTest < Chadcn::TestCase
  Settings = Chadcn::Chart::Polar::AxisSettings
  ROWS = [ { month: "A", value: 10 }, { month: "B", value: 30 }, { month: "C", value: 20 } ].freeze

  def series(key = :value) = Chadcn::Chart::Radar.new(data_key: key)

  def angle(layout: :centric, rows: ROWS, range: [ 90.0, -270.0 ], **changes)
    settings = Settings.implicit(:angle).with(**changes)
    Chadcn::Chart::Polar::Axis.new(settings, layout: layout, rows: rows, items: [ series ], range: range)
  end

  def radius(layout: :centric, rows: ROWS, range: [ 0.0, 100.0 ], **changes)
    settings = Settings.implicit(:radius).with(**changes)
    Chadcn::Chart::Polar::Axis.new(settings, layout: layout, rows: rows, items: [ series ], range: range)
  end

  test "the angle axis of a radar chart holds the categories, the radius axis the numbers" do
    assert_predicate angle, :categorical?
    assert_predicate angle, :category?
    refute_predicate radius, :categorical?
    refute_predicate radius, :category?
    refute_predicate angle(layout: :radial), :categorical?
    assert_predicate radius(layout: :radial), :categorical?
  end

  test "the angle ticks are the categories, each centered on its band, going clockwise from the top" do
    ticks = angle(data_key: :month).ticks

    assert_equal %w[A B C], ticks.map(&:value)
    assert_equal([ 90.0, -30.0, -150.0 ], ticks.map(&:coordinate).map { |value| value.round(9) })
    assert_in_delta 120.0, angle(data_key: :month).bandwidth
  end

  test "a category axis without a data key lists the row indexes" do
    assert_equal [ 0, 1, 2 ], angle.ticks.map(&:value)
  end

  test "the radius ticks are nice: an auto domain from zero to the data, five ticks, the domain widened to them" do
    axis = radius

    assert_equal [ 0.0, 32.0 ], axis.domain
    assert_equal [ 0.0, 8.0, 16.0, 24.0, 32.0 ], axis.ticks.map(&:value)
    assert_equal [ 0.0, 25.0, 50.0, 75.0, 100.0 ], axis.ticks.map(&:coordinate)
    assert_in_delta 37.5, axis.position_of(12.0)
  end

  test "a user domain and tick count shape the radius ticks, a reversed axis runs the other way" do
    axis = radius(domain: [ 0, 100 ], tick_count: 3)
    reversed = radius(domain: [ 0, 100 ], tick_count: 3, reversed: true)

    assert_equal [ 0.0, 50.0, 100.0 ], axis.ticks.map(&:coordinate)
    assert_equal [ 100.0, 50.0, 0.0 ], reversed.ticks.map(&:coordinate)
  end

  test "an angle listed twice (0 and 360) is one tick of the axis and two of the grid" do
    axis = angle(layout: :radial, range: [ 0.0, 360.0 ], domain: [ 0, 350 ], type: :number)

    assert_equal 8, axis.all_ticks.size
    assert_equal 7, axis.ticks.size
  end

  test "a number axis that holds the categories ticks at the value of every row" do
    axis = angle(data_key: :value, type: :number, domain: [ 0, 40 ])

    assert_equal [ 10, 30, 20 ], axis.ticks.map(&:value)
    assert_equal [ 0, 1, 2 ], axis.item_ticks.map(&:index)
  end

  test "no data is no scale" do
    refute_predicate angle(rows: []), :scaled?
    assert_empty angle(rows: []).ticks
  end

  test "the band size is the width of a band, or the least distance between two ticks" do
    assert_in_delta 120.0, angle.band_size
    assert_in_delta 15.625, radius.band_size
    assert_in_delta 120.0, angle.band_size(bar: true)
  end
end

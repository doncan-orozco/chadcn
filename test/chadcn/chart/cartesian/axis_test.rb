# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Cartesian::AxisTest < Chadcn::TestCase
  AxisSettings = Chadcn::Chart::Cartesian::AxisSettings
  Stacks = Chadcn::Chart::Cartesian::Stacks

  ROWS = [ { name: "A", v: 186, w: 80 }, { name: "B", v: 305, w: 200 }, { name: "C", v: 237, w: 120 } ].freeze

  def settings(kind = :x, **changes)
    base = kind == :x ? AxisSettings.implicit(:x) : AxisSettings.implicit(:y)
    base.with(hide: false, **changes)
  end

  def axis(settings, rows: ROWS, items: [], layout: :horizontal, chart_type: :bar, range: [ 0.0, 300.0 ], references: [], stack_offset: :none)
    stackable = items.select { |item| item.options[:stack_id] }
    stacks = Stacks.new(rows, stackable, offset: stack_offset)
    Chadcn::Chart::Cartesian::Axis.new(settings, layout: layout, chart_type: chart_type, rows: rows, items: items, stacks: stacks, references: references,
                                                 range: range, stack_offset: stack_offset)
  end

  def line(key, **) = Chadcn::Chart::Line.new(data_key: key, **)

  def bar(key, **) = Chadcn::Chart::Bar.new(data_key: key, **)

  test "a number axis takes its domain from the data and widens it to the nice ticks" do
    value = axis(settings(:y), items: [ bar(:v) ], range: [ 160.0, 0.0 ])

    assert_equal [ 0, 80, 160, 240, 320 ], value.nice_ticks
    assert_equal [ 0, 320 ], value.domain
    assert_in_delta 160.0, value.map(0), 0.0001
    assert_in_delta 0.0, value.map(320), 0.0001
    assert_equal :linear, value.scale_type
  end

  test "stacked series count by their sum" do
    value = axis(settings(:y), items: [ bar(:v, stack_id: "a"), bar(:w, stack_id: "a") ])

    assert_equal [ 0, 600 ], value.domain
  end

  test "an explicit domain is kept and gets ticks inside it" do
    value = axis(settings(:y, domain: [ 0, 400 ]), items: [ bar(:v) ])

    assert_equal [ 0, 400 ], value.domain
    assert_equal [ 0, 100, 200, 300, 400 ], value.nice_ticks
  end

  test "domain bounds can be dataMin and dataMax with an offset, or a callable" do
    assert_equal [ 176.0, 325.0 ], axis(settings(:y, domain: [ "dataMin - 10", "dataMax + 20" ], nice_ticks: :none), items: [ line(:v) ]).domain.map(&:to_f)
    assert_equal [ 186, 305 ], axis(settings(:y, domain: %w[dataMin dataMax], nice_ticks: :none), items: [ line(:v) ]).domain.map(&:to_i)
    assert_equal [ 0.0, 500.0 ], axis(settings(:y, domain: [ 0, ->(max) { max + 195 } ], nice_ticks: :none), items: [ line(:v) ]).domain
  end

  test "allow_data_overflow keeps an explicit domain narrower than the data" do
    clipped = axis(settings(:y, domain: [ 0, 200 ], allow_data_overflow: true, nice_ticks: :none), items: [ line(:v) ])
    widened = axis(settings(:y, domain: [ 0, 200 ], nice_ticks: :none), items: [ line(:v) ])

    assert_equal [ 0.0, 200.0 ], clipped.domain
    assert_equal [ 0.0, 305.0 ], widened.domain
  end

  test "nice_ticks none leaves d3 ticks, snap125 uses its own step" do
    plain = axis(settings(:y, nice_ticks: :none, tick_count: 4), items: [ line(:v) ])

    assert_nil plain.nice_ticks
    assert_equal [ 0.0, 305.0 ], plain.domain
    assert_equal [ 0, 100, 200, 300, 400, 500, 600 ], axis(settings(:y, nice_ticks: :snap125, tick_count: 7), items: [ line(:v) ]).nice_ticks.map(&:to_i)
  end

  test "a category axis lists the categories on a band scale, ticks centered; a line chart uses points" do
    band = axis(settings(data_key: :name))

    assert_equal %w[A B C], band.domain
    assert_equal :band, band.scale_type
    assert_equal [ 50.0, 150.0, 250.0 ], band.ticks.map(&:coordinate)
    assert_equal [ 0.0, 100.0, 200.0 ], band.item_ticks.map(&:coordinate)
    assert_in_delta 100.0, band.bandwidth

    point = axis(settings(data_key: :name), chart_type: :line)

    assert_equal :point, point.scale_type
    assert_equal [ 0.0, 150.0, 300.0 ], point.ticks.map(&:coordinate)
    assert_in_delta 0.0, point.bandwidth
  end

  test "without a data_key the categories are the row indexes; repeated categories are indexes too" do
    assert_equal [ 0, 1, 2 ], axis(settings).domain

    repeated = axis(settings(data_key: :name), rows: [ { name: "A" }, { name: "A" }, { name: "B" } ])

    assert_equal [ 0, 1, 2 ], repeated.domain
    assert_equal %w[A A B], repeated.ticks.map(&:value)
    assert_equal %w[A B], axis(settings(data_key: :name, allow_duplicated_category: false), rows: [ { name: "A" }, { name: "A" }, { name: "B" } ]).domain
  end

  test "reversed swaps the range; user ticks replace the computed ones" do
    assert_equal [ 250.0, 150.0, 50.0 ], axis(settings(data_key: :name, reversed: true)).ticks.map(&:coordinate)
    custom = axis(settings(:y, ticks: [ 0, 100, 250 ], domain: [ 0, 300 ]), items: [ bar(:v) ])

    assert_equal [ 0, 100, 250 ], custom.ticks.map(&:value)
  end

  test "an axis with nothing to draw has no scale" do
    empty = axis(settings(:y), rows: [], items: [ bar(:v) ])

    assert_not empty.scaled?
    assert_empty empty.ticks
    assert_nil empty.map(1)
  end

  test "references that extend the domain count" do
    value = axis(settings(:y, nice_ticks: :none), items: [ line(:v) ], references: [ { x: nil, y: 999 } ])

    assert_equal [ 0.0, 999.0 ], value.domain
  end

  test "stack_offset expand makes the domain 0 to 1" do
    value = axis(settings(:y), items: [ bar(:v, stack_id: "a"), bar(:w, stack_id: "a") ], stack_offset: :expand)

    assert_equal [ 0.0, 1.0 ], value.domain
  end

  test "band_size is the bandwidth, else the smallest distance between ticks" do
    assert_in_delta 100.0, axis(settings(data_key: :name)).band_size(bar: true)
    assert_in_delta 0.0, axis(settings(data_key: :name), chart_type: :line).band_size
    assert_operator axis(settings(:y, nice_ticks: :none, tick_count: 4), items: [ line(:v) ], range: [ 300.0, 0.0 ]).band_size, :>, 0
  end
end

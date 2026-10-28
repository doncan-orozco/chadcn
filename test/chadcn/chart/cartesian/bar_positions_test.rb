# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Cartesian::BarPositionsTest < Chadcn::TestCase
  BarPositions = Chadcn::Chart::Cartesian::BarPositions

  def bar(key, **options) = Chadcn::Chart::Bar.new(data_key: key, **options)

  def positions(bars, band: 51.6667, gap: 4, category_gap: "10%", global_size: nil, global_max: nil, child_max: nil)
    slots = BarPositions.slots(bars, global_size, 310)
    BarPositions.positions(slots, global_max, gap, category_gap, band, band, child_max)
  end

  test "stacks come first, in the order JavaScript gives object keys, then the bars alone" do
    slots = BarPositions.slots([ bar(:a), bar(:b, stack_id: "b"), bar(:c, stack_id: "10"), bar(:d, stack_id: "2"), bar(:e, stack_id: "b") ], nil, 310)

    assert_equal [ "2", "10", "b", nil ], slots.map(&:stack_id)
    assert_equal [ [ :d ], [ :c ], [ :b, :e ], [ :a ] ], slots.map(&:data_keys)
  end

  test "without a bar_size the band minus the category gap is shared, truncated to a whole pixel" do
    single = positions([ bar(:a) ]).first

    assert_equal 41.0, single.size
    assert_in_delta 5.1667, single.offset, 0.0001

    pair = positions([ bar(:a), bar(:b) ])

    assert_equal [ 18.0, 18.0 ], pair.map(&:size)
    assert_in_delta 22.0, pair[1].offset - pair[0].offset, 0.0001
  end

  test "max_bar_size narrows the bar and keeps it centered in its share" do
    narrowed = positions([ bar(:a) ], global_max: 20).first

    assert_equal 20, narrowed.size
    assert_in_delta 5.1667 + 10.5, narrowed.offset, 0.0001
    assert_equal 30, positions([ bar(:a) ], global_max: 20, child_max: 30).first.size
  end

  test "with a bar_size the group is centered and the gap kept while it fits" do
    sized = positions([ bar(:a, bar_size: 10), bar(:b, bar_size: 20) ], gap: 8)

    assert_equal [ 10, 20 ], sized.map(&:size)
    assert_equal 6.0, sized.first.offset
    assert_equal 18.0, sized[1].offset - sized[0].offset
  end

  test "bars too wide for the band lose the gap, then shrink to 90% of their share" do
    gapless = positions([ bar(:a, bar_size: 25), bar(:b, bar_size: 25) ], gap: 8)

    assert_equal 25.0, gapless[1].offset - gapless[0].offset

    shrunk = positions([ bar(:a, bar_size: 40), bar(:b, bar_size: 40) ], gap: 8)

    assert_in_delta 23.25, shrunk.first.size, 0.0001
  end

  test "bar_size is read from the chart too, as a share of the axis" do
    assert_equal 31.0, positions([ bar(:a) ], global_size: "10%").first.size
  end

  test "a bar finds its slot by stack id and data key" do
    bars = [ bar(:a), bar(:b, stack_id: "s") ]
    found = positions(bars)

    assert_equal "s", BarPositions.find(found, bars.last).stack_id
    assert_nil BarPositions.find(found, bar(:zzz))
    assert_nil BarPositions.positions([], nil, 4, "10%", 50, 50, nil)
  end
end

# frozen_string_literal: true

require "chadcn/test_case"
require_relative "oracle_helper"

class Chadcn::Chart::Shape::StackTest < Chadcn::TestCase
  include ChartOracle

  Stack = Chadcn::Chart::Shape::Stack

  test "series equals recharts getStackedData for the none and expand offsets" do
    ChartOracle.shape.fetch("stacks").each do |kase|
      series = Stack.series(kase["data"], kase["keys"], offset: kase["offset"])

      assert_equal kase["series"].size, series.size
      kase["series"].zip(series).each_with_index do |(expected, actual), index|
        assert_equal expected.size, actual.size
        expected.zip(actual).each_with_index do |(want, got), row|
          assert_all_close(want, got, "#{kase['offset']} series #{index} row #{row}")
        end
      end
    end
  end

  test "values are floats and a missing key counts as zero" do
    series = Stack.series([ { a: 1 }, { a: 2, b: 3 } ], %i[a b])

    assert_equal [ [ [ 0.0, 1.0 ], [ 0.0, 2.0 ] ], [ [ 1.0, 1.0 ], [ 2.0, 5.0 ] ] ], series
  end

  test "a reader block extracts the values" do
    rows = [ [ 1, 2 ], [ 3, 4 ] ]
    series = Stack.series(rows, [ 0, 1 ]) { |row, key| row[key] }

    assert_equal [ [ 0.0, 1.0 ], [ 0.0, 3.0 ] ], series[0]
    assert_equal [ [ 1.0, 3.0 ], [ 3.0, 7.0 ] ], series[1]
  end

  test "expand normalizes every column to one and keeps empty columns at zero" do
    series = Stack.series([ { a: 1, b: 3 }, { a: 0, b: 0 } ], %i[a b], offset: "expand")

    assert_equal [ [ 0.0, 0.25 ], [ 0.0, 0.0 ] ], series[0]
    assert_equal [ [ 0.25, 1.0 ], [ 0.0, 0.0 ] ], series[1]
  end

  test "a two-number array value is taken as a ready-made range and does not stack" do
    series = Stack.series([ { a: 5, b: [ 2, 8 ] }, { a: 1, b: [ 1 ] } ], %i[a b])

    assert_equal [ 2.0, 8.0 ], series[1][0]
    assert_equal [ 1.0, 1.0 ], series[1][1]
  end

  test "no keys and no rows give no series" do
    assert_empty Stack.series([ { a: 1 } ], [])
    assert_equal [ [] ], Stack.series([], [ :a ])
    assert_equal [ [], [] ], Stack.series([], %i[a b], offset: :expand)
  end

  test "an unknown offset raises" do
    assert_raises(ArgumentError) { Stack.series([ { a: 1 } ], [ :a ], offset: :wiggle) }
  end

  test "group_by_stack_id keeps the order of first appearance and stacks equal ids" do
    bars = [ { key: :a, id: "x" }, { key: :b, id: nil }, { key: :c, id: 1 }, { key: :d, id: "x" }, { key: :e, id: "1" }, { key: :f, id: nil } ]
    groups = Stack.group_by_stack_id(bars) { |bar| bar[:id] }

    keys = groups.map { |group| group.map { |bar| bar[:key] } }

    assert_equal [ %i[a d], [ :b ], %i[c e], [ :f ] ], keys
  end
end

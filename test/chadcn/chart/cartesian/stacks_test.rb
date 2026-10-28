# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Cartesian::StacksTest < Chadcn::TestCase
  Stacks = Chadcn::Chart::Cartesian::Stacks

  def series(key, stack_id: "a") = Chadcn::Chart::Bar.new(data_key: key, stack_id: stack_id)

  ROWS = [ { a: 1, b: 2 }, { a: 3, b: 4 }, { a: "5", b: nil } ].freeze

  test "series with the same stack id sit on each other, in order of declaration" do
    a = series(:a)
    b = series(:b)
    stacks = Stacks.new(ROWS, [ a, b ])

    assert_equal [ [ 0.0, 1.0 ], [ 0.0, 3.0 ], [ 0.0, 5.0 ] ], stacks.pairs(a)
    assert_equal [ [ 1.0, 3.0 ], [ 3.0, 7.0 ], [ 5.0, 5.0 ] ], stacks.pairs(b)
    assert_equal [ 0.0, 7.0 ], stacks.domain
  end

  test "reverse puts the later series at the bottom" do
    a = series(:a)
    b = series(:b)
    stacks = Stacks.new(ROWS, [ a, b ], reverse: true)

    assert_equal [ 0.0, 2.0 ], stacks.pairs(b).first
    assert_equal [ 2.0, 3.0 ], stacks.pairs(a).first
  end

  test "different stack ids do not stack, and a series that is not stacked has no pairs" do
    a = series(:a, stack_id: "x")
    b = series(:b, stack_id: "y")
    stacks = Stacks.new(ROWS, [ a, b ])

    assert_equal [ 0.0, 1.0 ], stacks.pairs(a).first
    assert_equal [ 0.0, 2.0 ], stacks.pairs(b).first
    assert_nil stacks.pairs(series(:a))
  end

  test "expand scales every column to 1" do
    a = series(:a)
    b = series(:b)
    stacks = Stacks.new(ROWS, [ a, b ], offset: :expand)

    assert_in_delta 1.0, stacks.pairs(b).first.last, 0.0001
    assert_in_delta 1.0 / 3, stacks.pairs(a).first.last, 0.0001
  end

  test "a pair of numbers is a ready-made range and a value that is not a number counts 0" do
    a = series(:a)
    stacks = Stacks.new([ { a: [ 2, 9 ] }, { a: "x" } ], [ a ])

    assert_equal [ [ 2.0, 9.0 ], [ 0.0, 0.0 ] ], stacks.pairs(a)
  end

  test "nothing stacked, or stacks spanning only zero, have no domain" do
    assert_nil Stacks.new(ROWS, []).domain
    assert_nil Stacks.new([ { a: 0 } ], [ series(:a) ]).domain
  end
end

# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Shape::PathTest < Chadcn::TestCase
  Path = Chadcn::Chart::Shape::Path

  test "builds move, line, bezier and close segments like d3-path" do
    path = Path.new
    path.move_to(10, 20)
    path.line_to(30.5, 40)
    path.bezier_to(1, 2, 3, 4, 5, 6)
    path.close

    assert_equal "M10,20L30.5,40C1,2,3,4,5,6Z", path.to_s
  end

  test "rounds every number to three digits by default" do
    path = Path.new
    path.move_to(1.23456, 2.0005)
    path.line_to(1 / 3.0, -0.0001)

    assert_equal "M1.235,2.001L0.333,0", path.to_s
  end

  test "digits sets the rounding and nil leaves the numbers as they are" do
    precise = Path.new(digits: 1)
    precise.move_to(1.26, 2.24)
    raw = Path.new(digits: nil)
    raw.move_to(1.23456789, 1e-7)

    assert_equal "M1.3,2.2", precise.to_s
    assert_equal "M1.23456789,1e-7", raw.to_s
  end

  test "an empty path is empty, prints an empty string and has no d" do
    path = Path.new

    assert_empty path
    assert_equal "", path.to_s
    assert_nil path.d
  end

  test "d is the path data once something is drawn" do
    path = Path.new
    path.move_to(0, 0)

    assert_equal "M0,0", path.d
    assert_not_empty path
  end

  test "close does nothing before the first move, as in d3" do
    path = Path.new
    path.close

    assert_nil path.d
  end

  test "close after a line without a move closes once, then does nothing" do
    path = Path.new
    path.line_to(1, 1)
    path.close
    path.close

    assert_equal "L1,1Z", path.d
  end

  test "close after a move keeps the pen down, so a second close closes again" do
    path = Path.new
    path.move_to(0, 0)
    path.close
    path.close

    assert_equal "M0,0ZZ", path.d
  end

  test "to_s returns a copy" do
    path = Path.new
    path.move_to(1, 1)
    path.to_s << "junk"

    assert_equal "M1,1", path.to_s
  end

  test "invalid digits raise" do
    assert_raises(ArgumentError) { Path.new(digits: -1) }
    assert_raises(ArgumentError) { Path.new(digits: "3") }
  end

  test "non-finite numbers print as JavaScript does" do
    path = Path.new
    path.move_to(Float::NAN, Float::INFINITY)

    assert_equal "MNaN,Infinity", path.to_s
  end
end

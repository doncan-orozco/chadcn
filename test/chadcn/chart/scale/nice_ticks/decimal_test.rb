# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Scale::NiceTicks::DecimalTest < Chadcn::TestCase
  Decimal = Chadcn::Chart::Scale::NiceTicks::Decimal

  test "exact is the Rational of the shortest decimal form of a Float" do
    assert_equal Rational(1, 10), Decimal.exact(0.1)
    assert_equal Rational(3, 10), Decimal.exact(0.3)
    assert_equal 5r, Decimal.exact(5)
    assert_equal Rational(1, 3), Decimal.exact(Rational(1, 3))
    assert_equal Rational(1, 10_000_000), Decimal.exact(1e-7)
  end

  test "nearest_double rounds a Rational through the Float it converts to" do
    assert_equal Decimal.exact(1 / 3.0), Decimal.nearest_double(Rational(1, 3))
    assert_equal Rational(1, 10), Decimal.nearest_double(Rational(1, 10))
  end

  test "center truncates toward zero modulo the step" do
    assert_equal 20r, Decimal.center(10r, 35r, 10r)
    assert_equal(-20r, Decimal.center(-35r, -10r, 10r))
  end

  test "digit_count is 1 for zero and counts the digits of the integer part" do
    assert_equal 1, Decimal.digit_count(0)
    assert_equal 3, Decimal.digit_count(305)
    assert_equal 0, Decimal.digit_count(0.5)
    assert_equal(-1, Decimal.digit_count(0.05))
  end

  test "range_step walks from start below stop and stops on a zero step" do
    assert_equal [ 0.0, 0.1, 0.2 ], Decimal.range_step(0r, Rational(25, 100), Rational(1, 10))
    assert_equal 100_000, Decimal.range_step(0r, 1r, 0r).size
  end
end

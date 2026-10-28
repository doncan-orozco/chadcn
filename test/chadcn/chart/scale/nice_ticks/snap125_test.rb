# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Scale::NiceTicks::Snap125Test < Chadcn::TestCase
  Snap125 = Chadcn::Chart::Scale::NiceTicks::Snap125

  test "step is the smallest of 1, 2, 2.5 and 5 times a power of ten not below the rough step" do
    assert_equal 1r, Snap125.step(1r, true, 0)
    assert_equal 2r, Snap125.step(Rational(13, 10), true, 0)
    assert_equal Rational(5, 2), Snap125.step(Rational(21, 10), true, 0)
    assert_equal 5r, Snap125.step(Rational(26, 10), true, 0)
    assert_equal 10r, Snap125.step(Rational(51, 10), true, 0)
  end

  test "a correction moves up the list, carrying into the next power of ten" do
    assert_equal 2r, Snap125.step(1r, true, 1)
    assert_equal 10r, Snap125.step(1r, true, 4)
  end

  test "allow_decimals false rounds the step up to a whole number" do
    assert_equal 1r, Snap125.step(Rational(3, 10), false, 0)
    assert_equal 3r, Snap125.step(Rational(21, 10), false, 0)
  end

  test "a rough step that is not positive gives a zero step" do
    assert_equal 0r, Snap125.step(0r, true, 0)
  end
end

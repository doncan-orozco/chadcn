# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Scale::NiceTicks::AdaptiveTest < Chadcn::TestCase
  Adaptive = Chadcn::Chart::Scale::NiceTicks::Adaptive

  test "step is a multiple of 0.05 of the order of magnitude of the rough step" do
    assert_equal 6r, Adaptive.step(Rational(53, 10), true, 0)
    assert_equal 60r, Adaptive.step(57r, true, 0)
    assert_equal Rational(1, 2), Adaptive.step(Rational(1, 2), true, 0)
  end

  test "a correction moves the step up by one multiple" do
    assert_equal 65r, Adaptive.step(57r, true, 1)
  end

  test "allow_decimals false rounds the step up to a whole number" do
    assert_equal 1r, Adaptive.step(Rational(3, 10), false, 0)
    assert_equal 6r, Adaptive.step(Rational(53, 10), false, 0)
  end

  test "a rough step that is not positive gives a zero step" do
    assert_equal 0r, Adaptive.step(0r, true, 0)
    assert_equal 0r, Adaptive.step(-1r, true, 0)
  end
end

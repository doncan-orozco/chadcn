# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Shape::NumberTest < Chadcn::TestCase
  Number = Chadcn::Chart::Shape::Number

  test "format prints integers and integral floats without a fraction" do
    assert_equal "1", Number.format(1)
    assert_equal "100", Number.format(100.0)
    assert_equal "-12", Number.format(-12)
    assert_equal "123456780000000", Number.format(1.234567800e14)
  end

  test "format prints the shortest round-trip digits like JavaScript" do
    assert_equal "0.30000000000000004", Number.format(0.1 + 0.2)
    assert_equal "-12.5", Number.format(-12.5)
    assert_equal "0.000123", Number.format(0.000123)
    assert_equal "0.000001", Number.format(1e-6)
  end

  test "format switches to the exponent form outside 1e-6 and 1e21" do
    assert_equal "1e+21", Number.format(1e21)
    assert_equal "1e-7", Number.format(1e-7)
    assert_equal "1.5e-7", Number.format(1.5e-7)
    assert_equal "1e+100", Number.format(1e100)
    assert_equal "-1.5e+22", Number.format(-1.5e22)
    assert_equal "1e+21", Number.format(10**21)
  end

  test "format keeps every digit below 1e21" do
    assert_equal "123456789012345680000", Number.format(123_456_789_012_345_680_000.0)
    assert_equal "250000000000000000000", Number.format(2.5e20)
    assert_equal "12345678901234567890", Number.format(12_345_678_901_234_567_890)
  end

  test "format prints negative zero as 0 and spells the non-finite numbers like JavaScript" do
    assert_equal "0", Number.format(-0.0)
    assert_equal "0", Number.format(0)
    assert_equal "NaN", Number.format(Float::NAN)
    assert_equal "Infinity", Number.format(Float::INFINITY)
    assert_equal "-Infinity", Number.format(-Float::INFINITY)
  end

  test "format takes Rational values" do
    assert_equal "0.5", Number.format(Rational(1, 2))
  end

  test "round_half_up is Math.round: ties go toward positive infinity" do
    assert_in_delta(3.0, Number.round_half_up(2.5))
    assert_in_delta(-2.0, Number.round_half_up(-2.5))
    assert_in_delta(-3.0, Number.round_half_up(-2.6))
    assert_in_delta(0.0, Number.round_half_up(0.49999999999999994))
    assert_in_delta(1.0, Number.round_half_up(0.5))
  end

  test "round_half_up returns non-finite numbers unchanged" do
    assert_predicate Number.round_half_up(Float::NAN), :nan?
    assert_equal Float::INFINITY, Number.round_half_up(Float::INFINITY)
  end

  test "round rounds half up to the digits" do
    assert_in_delta 2.001, Number.round(2.0005, 3)
    assert_in_delta 1.235, Number.round(1.2345, 3)
    assert_in_delta(-1.234, Number.round(-1.2345, 3))
    assert_in_delta 12.0, Number.round(11.5, 0)
    assert_in_delta 3.1416, Number.round(Math::PI, 4)
  end

  test "round normalizes negative zero" do
    assert_equal "0", Number.format(Number.round(-0.0001, 3))
    assert_not Number.round(-0.0001, 3).to_s.start_with?("-")
  end
end

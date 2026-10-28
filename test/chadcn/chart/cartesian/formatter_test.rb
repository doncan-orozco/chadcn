# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Cartesian::FormatterTest < Chadcn::TestCase
  Formatter = Chadcn::Chart::Cartesian::Formatter

  test "slice follows String#slice of JavaScript, clamping and returning an empty range" do
    assert_equal "Jan", Formatter.slice("January", 0, 3)
    assert_equal "Jan", Formatter.slice("January", -10, 3)
    assert_equal "Januar", Formatter.slice("January", 0, -1)
    assert_equal "ry", Formatter.slice("January", 5, 9)
    assert_equal "", Formatter.slice("January", 3, 1)
    assert_equal "uary", Formatter.slice("January", 3)
    assert_equal "12", Formatter.slice(123.0, 0, 2)
  end

  test "locale groups thousands and keeps at most three fraction digits, half away from zero" do
    assert_equal "1,234,567.891", Formatter.locale(1_234_567.891)
    assert_equal "1,000", Formatter.locale(1000)
    assert_equal "0.001", Formatter.locale(0.0005)
    assert_equal "1.235", Formatter.locale(1.2345)
    assert_equal "-1,500.5", Formatter.locale(-1500.5)
    assert_equal "abc", Formatter.locale("abc")
  end

  test "percent multiplies by 100 and appends a sign" do
    assert_equal "25%", Formatter.percent(0.25)
    assert_equal "1,200%", Formatter.percent(12)
    assert_equal "x", Formatter.percent("x")
  end

  test "resolve turns a named formatter into a callable and passes callables through" do
    assert_nil Formatter.resolve(nil)
    assert_equal "Feb", Formatter.resolve({ slice: [ 0, 3 ] }).call("February", 1)
    assert_equal "1,000", Formatter.resolve(:locale).call(1000, 0)
    assert_equal "50%", Formatter.resolve("percent").call(0.5, 0)
    custom = ->(value, index) { "#{index}#{value}" }

    assert_same custom, Formatter.resolve(custom)
  end

  test "resolve rejects what is neither callable nor named" do
    assert_raises(ArgumentError) { Formatter.resolve(:shout) }
    assert_raises(ArgumentError) { Formatter.resolve({ upcase: [] }) }
    assert_raises(ArgumentError) { Formatter.resolve({ slice: "x" }) }
    assert_raises(ArgumentError) { Formatter.resolve(42) }
  end

  test "locale_string is the JavaScript toLocaleString of a number: infinities, NaN, negative zero, text as String" do
    assert_equal "∞", Formatter.locale_string(Float::INFINITY)
    assert_equal "-∞", Formatter.locale_string(-Float::INFINITY)
    assert_equal "NaN", Formatter.locale_string(Float::NAN)
    assert_equal "-0", Formatter.locale_string(-0.0)
    assert_equal "-0", Formatter.locale_string(-0.0004)
    assert_equal "12,345,678,901,234,567,890", Formatter.locale_string(12_345_678_901_234_567_890)
    assert_equal "abc", Formatter.locale_string("abc")
    assert_equal "", Formatter.locale_string(nil)
  end

  test "locale coerces numeric text and spells the infinities the same way" do
    assert_equal "1,234.5", Formatter.locale("1234.5")
    assert_equal "∞", Formatter.locale(Float::INFINITY)
    assert_equal "-0", Formatter.locale(-0.0)
    assert_equal "abc", Formatter.locale("abc")
  end
end

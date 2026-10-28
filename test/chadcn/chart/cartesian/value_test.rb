# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Cartesian::ValueTest < Chadcn::TestCase
  Value = Chadcn::Chart::Cartesian::Value

  test "read finds a key by symbol or string, and calls a callable with the row" do
    assert_equal 1, Value.read({ a: 1 }, :a)
    assert_equal 2, Value.read({ "a" => 2 }, :a)
    assert_equal 3, Value.read({ a: 3 }, "a")
    assert_equal 4, Value.read({ a: 2 }, ->(row) { row[:a] * 2 })
    assert_nil Value.read({ a: 1 }, :b)
    assert_nil Value.read(nil, :a)
    assert_nil Value.read({ a: 1 }, nil)
  end

  test "number accepts finite numbers and numeric strings as JavaScript does, nothing else" do
    assert_equal 5.0, Value.number(5)
    assert_equal 1.5, Value.number("1.5")
    assert_equal 1000.0, Value.number(" 1e3 ")
    assert_equal 0.0, Value.number("")
    assert_nil Value.number("12px")
    assert_nil Value.number("0x10")
    assert_nil Value.number(Float::NAN)
    assert_nil Value.number(Float::INFINITY)
    assert_nil Value.number(nil)
    assert_nil Value.number([ 1 ])
  end

  test "numeric? is true for numbers that are not NaN, infinities included" do
    assert Value.numeric?(3)
    assert Value.numeric?(Float::INFINITY)
    assert_not Value.numeric?(Float::NAN)
    assert_not Value.numeric?("3")
  end

  test "text prints numbers like JavaScript, nil as an empty string" do
    assert_equal "5", Value.text(5.0)
    assert_equal "0.1", Value.text(0.1)
    assert_equal "", Value.text(nil)
    assert_equal "Jan", Value.text("Jan")
  end

  test "percent is a number, a numeric string or a share of the total; validate caps it" do
    assert_equal 4.0, Value.percent(4, 100)
    assert_in_delta 10.0, Value.percent("10%", 100), 0.0001
    assert_equal 7.0, Value.percent("7", 100)
    assert_equal 0.0, Value.percent("10%", nil)
    assert_equal 0.0, Value.percent(nil, 100)
    assert_equal 5.0, Value.percent("abc", 100, 5.0)
    assert_equal 100, Value.percent(250, 100, 0.0, validate: true)
  end
end

# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::JsMathTest < Chadcn::TestCase
  JsMath = Chadcn::Chart::JsMath

  test "round is Math.round: ties go toward positive infinity" do
    assert_in_delta 3.0, JsMath.round(2.5), 1e-9
    assert_in_delta(-2.0, JsMath.round(-2.5), 1e-9)
    assert_in_delta(-3.0, JsMath.round(-2.6), 1e-9)
    assert_in_delta 0.0, JsMath.round(0.49999999999999994), 1e-9
    assert_in_delta 1.0, JsMath.round(0.5), 1e-9
  end

  test "round returns non-finite numbers unchanged" do
    assert_predicate JsMath.round(Float::NAN), :nan?
    assert_equal Float::INFINITY, JsMath.round(Float::INFINITY)
  end

  test "floor and ceil let the infinities and NaN through" do
    assert_in_delta 2.0, JsMath.floor(2.7), 1e-9
    assert_in_delta(-3.0, JsMath.floor(-2.1), 1e-9)
    assert_in_delta 3.0, JsMath.ceil(2.1), 1e-9
    assert_equal(-Float::INFINITY, JsMath.floor(-Float::INFINITY))
    assert_equal Float::INFINITY, JsMath.ceil(Float::INFINITY)
    assert_predicate JsMath.floor(Float::NAN), :nan?
    assert_predicate JsMath.ceil(Float::NAN), :nan?
  end

  test "log10 is NaN below zero and -Infinity at zero instead of raising" do
    assert_in_delta 2.0, JsMath.log10(100.0), 1e-9
    assert_predicate JsMath.log10(-1.0), :nan?
    assert_equal(-Float::INFINITY, JsMath.log10(0.0))
  end
end

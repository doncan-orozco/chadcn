# frozen_string_literal: true

require "chadcn/test_case"
require_relative "../shape/oracle_helper"

class Chadcn::Chart::Scale::NiceTicksTest < Chadcn::TestCase
  include ChartOracle

  NiceTicks = Chadcn::Chart::Scale::NiceTicks
  INFINITY = Float::INFINITY

  test "values equal recharts getNiceTickValues in both modes" do
    ChartOracle.cases(:scale, "nice_ticks", minimum: 30).each do |kase|
      ticks = NiceTicks.values(kase["min"], kase["max"], kase["count"], allow_decimals: kase["allow_decimals"], mode: kase["mode"])

      assert_all_close(kase["ticks"], ticks, "values #{kase.slice('min', 'max', 'count', 'allow_decimals', 'mode')}")
    end
  end

  test "fixed_domain equals recharts getTickValuesFixedDomain in both modes" do
    ChartOracle.cases(:scale, "fixed_domain", minimum: 14).each do |kase|
      ticks = NiceTicks.fixed_domain(kase["min"], kase["max"], kase["count"], allow_decimals: kase["allow_decimals"], mode: kase["mode"])

      assert_all_close(kase["ticks"], ticks, "fixed #{kase.slice('min', 'max', 'count', 'allow_decimals', 'mode')}")
    end
  end

  test "a descending domain gives the ticks of the ascending one, reversed" do
    assert_equal NiceTicks.values(0, 305, 5).reverse, NiceTicks.values(305, 0, 5)
    assert_equal NiceTicks.fixed_domain(0, 400, 5).reverse, NiceTicks.fixed_domain(400, 0, 5)
  end

  test "values defaults to six ticks" do
    assert_equal NiceTicks.values(0, 100, 6), NiceTicks.values(0, 100)
  end

  test "a single value is centered in the ticks" do
    assert_equal [ 0.0, 1.0, 2.0, 3.0, 4.0 ], NiceTicks.values(2.5, 2.5, 5)
    assert_equal [ 0.2, 0.3, 0.4 ], NiceTicks.values(0.37, 0.37, 3)
    assert_equal [ -5.0, -4.0, -3.0, -2.0 ], NiceTicks.values(-4, -4, 4, allow_decimals: false)
    assert_equal [ 7.0 ], NiceTicks.values(7, 7, 1)
  end

  test "an infinite bound gives ticks of that infinity" do
    assert_equal [ 0.0, INFINITY, INFINITY, INFINITY ], NiceTicks.values(0, INFINITY, 4)
    assert_equal [ INFINITY, INFINITY, INFINITY, 0.0 ], NiceTicks.values(INFINITY, 0, 4)
    assert_equal [ -INFINITY, -INFINITY, 5.0 ], NiceTicks.values(-INFINITY, 5, 3)
    assert_equal [ 5.0, -INFINITY, -INFINITY ], NiceTicks.values(5, -INFINITY, 3)
    assert_equal [ 0.0, INFINITY ], NiceTicks.fixed_domain(0, INFINITY, 4)
  end

  test "an infinite bound gives count - 1 infinities, none below two ticks" do
    assert_equal [ 0.0 ], NiceTicks.values(0, INFINITY, 1)
    assert_equal [ 0.0 ], NiceTicks.values(0, INFINITY, 0)
    assert_equal [ 5.0 ], NiceTicks.values(-INFINITY, 5, 0)
    assert_equal [ 0.0, INFINITY ], NiceTicks.values(0, INFINITY, 2)
  end

  test "a NaN bound has no ticks and raises" do
    assert_raises(ArgumentError) { NiceTicks.values(Float::NAN, 5) }
    assert_raises(ArgumentError) { NiceTicks.fixed_domain(0, Float::NAN, 4) }
  end

  test "allow_decimals false keeps the ticks whole" do
    assert_equal [ 0.0, 1.0, 2.0 ], NiceTicks.values(0, 1, 3, allow_decimals: false)
  end

  test "decimal steps do not accumulate float noise" do
    assert_equal [ 0.09, 0.18, 0.27, 0.36 ], NiceTicks.values(0.1, 0.35, 4)
  end

  test "the mode accepts strings and symbols and rejects anything else" do
    assert_equal NiceTicks.values(0, 305, 5, mode: :snap125), NiceTicks.values(0, 305, 5, mode: "snap125")
    assert_raises(ArgumentError) { NiceTicks.values(0, 10, 5, mode: :other) }
    assert_raises(ArgumentError) { NiceTicks.fixed_domain(0, 10, 5, mode: "other") }
  end
end

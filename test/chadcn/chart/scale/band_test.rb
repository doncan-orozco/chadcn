# frozen_string_literal: true

require "chadcn/test_case"
require_relative "../shape/oracle_helper"

class Chadcn::Chart::Scale::BandTest < Chadcn::TestCase
  include ChartOracle

  Band = Chadcn::Chart::Scale::Band

  test "positions, step and bandwidth equal d3 scaleBand" do
    ChartOracle.cases(:scale, "band", minimum: 6).each do |kase|
      band = Band.new(count: kase["count"], range: kase["range"], **ChartOracle.keywords(kase["opts"]))
      positions = Array.new(kase["count"]) { |index| band.call(index) }

      assert_all_close(kase["positions"], positions, "band #{kase.slice('count', 'range', 'opts')}")
      assert_close(kase["step"], band.step, "step #{kase.slice('count', 'range', 'opts')}")
      assert_close(kase["bandwidth"], band.bandwidth, "bandwidth #{kase.slice('count', 'range', 'opts')}")
    end
  end

  test "a reversed range lays the bands out from the end" do
    band = Band.new(count: 3, range: [ 90, 0 ])

    assert_equal [ 60.0, 30.0, 0.0 ], Array.new(3) { |index| band.call(index) }
    assert_in_delta 30.0, band.bandwidth, 1e-9
  end

  test "padding sets both paddings, the explicit keywords win" do
    both = Band.new(count: 4, range: [ 0, 100 ], padding: 0.3)
    explicit = Band.new(count: 4, range: [ 0, 100 ], padding: 0.3, padding_inner: 0.1, padding_outer: 0)

    assert_in_delta 0.3, both.padding_inner, 1e-9
    assert_in_delta 0.3, both.padding_outer, 1e-9
    assert_in_delta 0.1, explicit.padding_inner, 1e-9
    assert_in_delta 0.0, explicit.padding_outer, 1e-9
  end

  test "inner padding is capped at 1 and align is clamped to 0..1" do
    band = Band.new(count: 2, range: [ 0, 10 ], padding_inner: 5, align: 7)

    assert_in_delta 1.0, band.padding_inner, 1e-9
    assert_in_delta 1.0, band.align, 1e-9
    assert_in_delta 0.0, band.bandwidth, 1e-9
  end

  test "align moves the bands inside the range" do
    start = Band.new(count: 2, range: [ 0, 100 ], padding_outer: 1, align: 0)
    finish = Band.new(count: 2, range: [ 0, 100 ], padding_outer: 1, align: 1)

    assert_operator start.call(0), :<, finish.call(0)
  end

  test "an index outside the categories has no position" do
    band = Band.new(count: 3, range: [ 0, 30 ])

    assert_nil band.call(3)
    assert_nil band.call(-1)
    assert_nil band.call("a")
  end

  test "bands are immutable and a range of one value raises" do
    assert_predicate Band.new(count: 1, range: [ 0, 1 ]), :frozen?
    assert_raises(ArgumentError) { Band.new(count: 1, range: [ 0 ]) }
  end
end

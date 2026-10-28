# frozen_string_literal: true

require "chadcn/test_case"
require_relative "../shape/oracle_helper"

class Chadcn::Chart::Scale::LinearTest < Chadcn::TestCase
  include ChartOracle

  Linear = Chadcn::Chart::Scale::Linear

  test "ticks equal d3-array ticks" do
    ChartOracle.cases(:scale, "ticks", minimum: 13).each do |kase|
      scale = Linear.new(domain: [ kase["start"], kase["stop"] ])

      assert_all_close(kase["ticks"], scale.ticks(kase["count"]), "ticks #{kase.slice('start', 'stop', 'count')}")
    end
  end

  test "increment equals d3-array tickIncrement, infinite where d3 reports an unusable step" do
    ChartOracle.cases(:scale, "ticks", minimum: 13).each do |kase|
      increment = Linear.new(domain: [ kase["start"], kase["stop"] ]).increment(kase["count"])

      assert_close(kase["increment"], increment, "increment #{kase.slice('start', 'stop', 'count')}")
    end
  end

  test "ticks of a descending domain come in descending order" do
    ChartOracle.cases(:scale, "descending_ticks", minimum: 2).each do |kase|
      scale = Linear.new(domain: [ kase["start"], kase["stop"] ])

      assert_all_close(kase["ticks"], scale.ticks(kase["count"]), "descending #{kase.slice('start', 'stop', 'count')}")
    end
  end

  test "ticks are empty for a count of zero and a single value for a zero-width domain" do
    assert_empty Linear.new(domain: [ 0, 10 ]).ticks(0)
    assert_equal [ 3.0 ], Linear.new(domain: [ 3, 3 ]).ticks(5)
  end

  test "ticks default to ten" do
    assert_equal Linear.new(domain: [ 0, 1 ]).ticks(10), Linear.new(domain: [ 0, 1 ]).ticks
  end

  test "nice equals d3 linear.nice" do
    ChartOracle.cases(:scale, "nice", minimum: 8).each do |kase|
      niced = Linear.new(domain: [ kase["start"], kase["stop"] ]).nice(kase["count"])

      assert_all_close(kase["domain"], niced.domain, "nice #{kase.slice('start', 'stop', 'count')}")
    end
  end

  test "nice of a descending domain is the nice of the ascending one, reversed" do
    ascending = Linear.new(domain: [ 0, 186 ]).nice(5).domain
    descending = Linear.new(domain: [ 186, 0 ]).nice(5).domain

    assert_equal ascending.reverse, descending
  end

  test "nice leaves a zero-width domain alone, as d3 does" do
    scale = Linear.new(domain: [ 7, 7 ], range: [ 0, 1 ])

    assert_equal [ 7.0, 7.0 ], scale.nice(5).domain
  end

  test "call maps like d3 scaleLinear, extrapolating outside the domain" do
    ChartOracle.cases(:scale, "linear", minimum: 3).each do |kase|
      scale = Linear.new(domain: kase["domain"], range: kase["range"])
      mapped = kase["values"].map { |value| scale.call(value) }

      assert_all_close(kase["mapped"], mapped, "linear #{kase.slice('domain', 'range')}")
    end
  end

  test "call maps a descending domain" do
    scale = Linear.new(domain: [ 10, 0 ], range: [ 0, 100 ])

    assert_in_delta 100.0, scale.call(0), 1e-9
    assert_in_delta 0.0, scale.call(10), 1e-9
    assert_in_delta 75.0, scale.call(2.5), 1e-9
  end

  test "call returns nil for nil and NaN" do
    scale = Linear.new

    assert_nil scale.call(nil)
    assert_nil scale.call(Float::NAN)
  end

  test "defaults are the unit interval like d3" do
    scale = Linear.new

    assert_equal [ 0.0, 1.0 ], scale.domain
    assert_equal [ 0.0, 1.0 ], scale.range
    assert_in_delta 0.25, scale.call(0.25), 1e-9
  end

  test "scales are immutable and the with_ methods return new scales" do
    scale = Linear.new(domain: [ 0, 10 ], range: [ 0, 100 ])
    wider = scale.with_domain([ 0, 20 ])
    shifted = scale.with_range([ 100, 200 ])

    assert_predicate scale, :frozen?
    assert_predicate scale.domain, :frozen?
    assert_equal [ 0.0, 10.0 ], scale.domain
    assert_equal [ 0.0, 20.0 ], wider.domain
    assert_equal [ 0.0, 100.0 ], wider.range
    assert_equal [ 100.0, 200.0 ], shifted.range
    assert_in_delta 150.0, shifted.call(5), 1e-9
  end

  test "a domain or range that is not two values raises" do
    assert_raises(ArgumentError) { Linear.new(domain: [ 0, 1, 2 ]) }
    assert_raises(ArgumentError) { Linear.new(range: [ 1 ]) }
  end
end

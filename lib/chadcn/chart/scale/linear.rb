# frozen_string_literal: true

# d3-scale `scaleLinear` over a two-value domain: maps a number of the domain onto the range, with the d3 tick helpers (d3-array
# `ticks`, `tickIncrement`) and `nice`. Immutable; the "setters" return a new scale.
#
# @api private
class Chadcn::Chart::Scale::Linear
  JsMath = Chadcn::Chart::Shape::JsMath
  # sqrt(50), sqrt(10), sqrt(2): the thresholds d3-array ticks.js uses to pick 1, 2, 5 or 10 as the step factor.
  E10 = Math.sqrt(50)
  E5 = Math.sqrt(10)
  E2 = Math.sqrt(2)
  # d3-scale linear.js `nice` gives up after this many refinements.
  NICE_ITERATIONS = 10

  private_constant :JsMath, :E10, :E5, :E2, :NICE_ITERATIONS

  # @api private
  # @return [Array<Float>] the two domain values (may be descending)
  attr_reader :domain

  # @api private
  # @return [Array<Float>] the two range values (may be descending)
  attr_reader :range

  # @api private
  # @param domain [Array<Numeric>] two values, `[0, 1]` by default like d3
  # @param range [Array<Numeric>] two values, `[0, 1]` by default like d3
  def initialize(domain: [ 0, 1 ], range: [ 0, 1 ])
    raise ArgumentError, "domain: and range: take two values each (got #{domain.size} and #{range.size})" unless domain.size == 2 && range.size == 2

    @domain = domain.map(&:to_f).freeze
    @range = range.map(&:to_f).freeze
    freeze
  end

  # @api private
  # @param domain [Array<Numeric>]
  # @return [Chadcn::Chart::Scale::Linear] a scale with another domain and the same range
  def with_domain(domain) = self.class.new(domain: domain, range: @range)

  # @api private
  # @param range [Array<Numeric>]
  # @return [Chadcn::Chart::Scale::Linear] a scale with another range and the same domain
  def with_range(range) = self.class.new(domain: @domain, range: range)

  # Maps a domain value onto the range, extrapolating outside the domain (no clamping), with d3's order of float operations. A
  # zero-width domain maps everything to the middle of the range.
  #
  # @api private
  # @param value [Numeric, nil]
  # @return [Float, nil] nil for a nil or NaN input (d3's `unknown`)
  def call(value)
    return nil if value.nil? || (value.respond_to?(:nan?) && value.nan?)

    d0, d1 = @domain
    r0, r1 = @range
    d0, d1, r0, r1 = d1, d0, r1, r0 if d1 < d0
    width = d1 - d0
    t = width.zero? ? 0.5 : (value - d0) / width
    (r0 * (1 - t)) + (r1 * t)
  end

  # d3-array `ticks(domain[0], domain[1], count)`: about `count` rounded values inside the domain, in the order of the domain.
  #
  # @api private
  # @param count [Numeric] approximate number of ticks (d3's default is 10)
  # @return [Array<Float>]
  def ticks(count = 10)
    start, stop = @domain
    return [] unless count.positive?
    return [ start ] if start == stop

    reverse = stop < start
    i1, i2, inc = reverse ? tick_spec(stop, start, count) : tick_spec(start, stop, count)
    return [] unless i1.finite? && i2.finite? && i2 >= i1

    first = i1.to_i
    last = i2.to_i
    indexes = reverse ? last.downto(first) : first.upto(last)
    indexes.map { |i| inc.negative? ? i / -inc : i * inc }
  end

  # d3-array `tickIncrement(domain[0], domain[1], count)`: the tick step, or its negated reciprocal when the step is below 1 (so
  # 0.1 is reported as -10), which keeps tick values free of float noise.
  #
  # @api private
  # @param count [Numeric]
  # @return [Float]
  def increment(count = 10)
    start, stop = @domain
    tick_spec(start, stop, count)[2]
  end

  # d3-scale linear `nice(count)`: expands the domain to round values, in the direction of the domain. A domain d3 cannot refine (zero
  # width, non-finite, or still moving after 10 passes) is returned unchanged.
  #
  # @api private
  # @param count [Numeric]
  # @return [Chadcn::Chart::Scale::Linear]
  def nice(count = 10)
    start, stop = @domain
    reversed = stop < start
    start, stop = stop, start if reversed
    previous = nil
    NICE_ITERATIONS.times do
      step = tick_spec(start, stop, count)[2]
      return with_domain(reversed ? [ stop, start ] : [ start, stop ]) if step == previous

      if step.positive?
        start = JsMath.floor(start / step) * step
        stop = JsMath.ceil(stop / step) * step
      elsif step.negative?
        start = JsMath.ceil(start * step) / step
        stop = JsMath.floor(stop * step) / step
      else
        break
      end
      previous = step
    end
    self
  end

  private

  # d3-array ticks.js `tickSpec` (ticks.js:7-29): [first index, last index, increment] where the ticks are `index * inc`, or
  # `index / -inc` when inc is negative. Floats throughout, as in JavaScript (NaN and Infinity flow through instead of raising).
  def tick_spec(start, stop, count)
    step = (stop - start) / [ 0, count ].max
    power = JsMath.floor(JsMath.log10(step))
    error = step / (10.0**power)
    factor = tick_factor(error)
    if power.negative?
      inc = (10.0**-power) / factor
      i1 = JsMath.round(start * inc)
      i2 = JsMath.round(stop * inc)
      i1 += 1 if i1 / inc < start
      i2 -= 1 if i2 / inc > stop
      inc = -inc
    else
      inc = (10.0**power) * factor
      i1 = JsMath.round(start / inc)
      i2 = JsMath.round(stop / inc)
      i1 += 1 if i1 * inc < start
      i2 -= 1 if i2 * inc > stop
    end
    return tick_spec(start, stop, count * 2) if i2 < i1 && count >= 0.5 && count < 2

    [ i1, i2, inc ]
  end

  # 10, 5, 2 or 1: the multiple of the power of ten closest to the wanted step (NaN gives 1).
  def tick_factor(error)
    return 10 if error >= E10
    return 5 if error >= E5

    error >= E2 ? 2 : 1
  end
end

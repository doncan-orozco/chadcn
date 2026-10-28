# frozen_string_literal: true

# The tick values recharts computes for a numeric axis (util/scale/getNiceTickValues.js): a step that reads well (1, 2, 2.5, 5 ...)
# and ticks that cover the data, possibly beyond it. This, not d3's `ticks`, is what recharts renders.
#
# recharts does the arithmetic in decimal.js-light so that 0.1 + 0.2 stays 0.3; here it is exact Rational arithmetic on the shortest
# decimal form of each Float ({Decimal}), which rounds the same way for the ranges a chart shows. The two step algorithms are
# {Adaptive} (the default, `mode: :auto`) and {Snap125} (`mode: :snap125`).
#
# @api private
module Chadcn::Chart::Scale::NiceTicks
  class << self
    # getNiceTickValues: ticks that cover `min..max` and are round numbers. A single-value domain is centered in a few ticks; a
    # descending domain gives the ticks in descending order; an infinite bound gives ticks of that infinity (`count - 1` of them
    # next to the finite bound, none when `count` is 0 or 1, where recharts' `range(0, count - 1)` is empty).
    #
    # @api private
    # @param min [Numeric]
    # @param max [Numeric]
    # @param count [Integer] number of ticks wanted (at least 2 are returned for a real domain)
    # @param allow_decimals [Boolean] false rounds the step up to a whole number
    # @param mode [Symbol, String] :auto or :snap125
    # @return [Array<Float>]
    # @raise [ArgumentError] on an unknown mode or a NaN bound
    def values(min, max, count = 6, allow_decimals: true, mode: :auto)
      strategy = step_strategy(mode)
      low, high = bounds(min, max)
      return unbounded(min > max, low, high, count) if low == -Float::INFINITY || high == Float::INFINITY
      return single_value(low, count, allow_decimals) if low == high

      step, tick_min, tick_max = calculate_step(low, high, [ count, 2 ].max, allow_decimals, 0, strategy)
      ticks = Decimal.range_step(tick_min, tick_max + (Rational(1, 10) * step), step)
      min > max ? ticks.reverse : ticks
    end

    # getTickValuesFixedDomain: ticks inside `min..max` (both ends are ticks) when the axis domain is fixed.
    #
    # @api private
    # @param min [Numeric]
    # @param max [Numeric]
    # @param count [Integer] number of ticks wanted (at least 2)
    # @param allow_decimals [Boolean] false rounds every tick to a whole number
    # @param mode [Symbol, String] :auto or :snap125
    # @return [Array<Float>]
    # @raise [ArgumentError] on an unknown mode or a NaN bound
    def fixed_domain(min, max, count, allow_decimals: true, mode: :auto)
      strategy = step_strategy(mode)
      low, high = bounds(min, max)
      return [ min.to_f, max.to_f ] if low == -Float::INFINITY || high == Float::INFINITY
      return [ low.to_f ] if low == high

      step = strategy.step((Decimal.exact(high) - Decimal.exact(low)) / ([ count, 2 ].max - 1), allow_decimals, 0)
      ticks = Decimal.range_step(Decimal.exact(low), Decimal.exact(high), step) + [ high.to_f ]
      ticks = ticks.map { |tick| Chadcn::Chart::Shape::JsMath.round(tick) } unless allow_decimals
      min > max ? ticks.reverse : ticks
    end

    private

    def step_strategy(mode)
      case mode.to_sym
      when :auto then Chadcn::Chart::Scale::NiceTicks::Adaptive
      when :snap125 then Chadcn::Chart::Scale::NiceTicks::Snap125
      else raise ArgumentError, "unknown nice ticks mode #{mode.inspect}, expected one of auto, snap125"
      end
    end

    # The bounds in ascending order. recharts compares with `>` and so lets a NaN through to produce garbage; there is no sensible
    # tick list for it, so it is refused.
    def bounds(min, max)
      raise ArgumentError, "a NaN bound has no ticks: #{[ min, max ].inspect}" if [ min, max ].any? { |bound| bound.respond_to?(:nan?) && bound.nan? }

      [ min, max ].minmax
    end

    # calculateStep: [step, first tick, last tick] with the number of ticks equal to `count`, 0 inside the ticks when the domain spans
    # it, retried with a larger step while the ticks would not fit.
    def calculate_step(min, max, count, allow_decimals, correction, strategy)
      return [ 0r, 0r, 0r ] unless ((max.to_f - min.to_f) / (count - 1)).finite?

      step = strategy.step((Decimal.exact(max) - Decimal.exact(min)) / (count - 1), allow_decimals, correction)
      middle = 0.between?(min, max) ? 0r : Decimal.center(Decimal.exact(min), Decimal.exact(max), step)
      below = ((middle - Decimal.exact(min)) / step).to_f.ceil
      above = ((Decimal.exact(max) - middle) / step).to_f.ceil
      needed = below + above + 1
      return calculate_step(min, max, count, allow_decimals, correction + 1, strategy) if needed > count

      if needed < count
        max.positive? ? above += count - needed : below += count - needed
      end
      [ step, middle - (below * step), middle + (above * step) ]
    end

    # getTickOfSingleValue: `count` ticks around one value, 1 apart (a power of ten below 1 for a fraction below 1).
    def single_value(value, count, allow_decimals)
      step = 1r
      middle = Decimal.exact(value)
      if middle.denominator != 1 && allow_decimals
        if value.abs < 1
          step = 10r**(Decimal.digit_count(value) - 1)
          middle = Rational((middle / step).to_f.floor) * step
        elsif value.abs > 1
          middle = Rational(value.floor)
        end
      elsif value.zero?
        middle = Rational((count - 1) / 2)
      elsif !allow_decimals
        middle = Rational(value.floor)
      end
      center_index = (count - 1) / 2
      Array.new([ count, 0 ].max) { |i| (middle + ((i - center_index) * step)).to_f }
    end

    # The branch of getNiceTickValues for an infinite bound: the finite bound and `count - 1` infinities (none below 2 ticks).
    def unbounded(descending, low, high, count)
      infinities = Array.new([ count - 1, 0 ].max)
      ticks = high == Float::INFINITY ? [ low.to_f ] + infinities.map { Float::INFINITY } : infinities.map { -Float::INFINITY } + [ high.to_f ]
      descending ? ticks.reverse : ticks
    end
  end
end

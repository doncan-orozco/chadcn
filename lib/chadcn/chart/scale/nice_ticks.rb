# frozen_string_literal: true

# The tick values recharts computes for a numeric axis (util/scale/getNiceTickValues.js): a step that reads well (1, 2, 2.5, 5 ...)
# and ticks that cover the data, possibly beyond it. This, not d3's `ticks`, is what recharts renders.
#
# recharts does the arithmetic in decimal.js-light so that 0.1 + 0.2 stays 0.3; here it is exact Rational arithmetic on the shortest
# decimal form of each Float, which rounds the same way for the ranges a chart shows.
#
# @api private
module Chadcn::Chart::Scale::NiceTicks
  # recharts' two step algorithms (`niceTicks` of the axis): the adaptive default and the opt-in 1-2-2.5-5 snapping.
  MODES = %i[auto snap125].freeze
  # The "nice" mantissas of snap125.
  SNAP_STEPS = [ 1r, 2r, 5r / 2, 5r ].freeze
  # rangeStep stops here, as a guard against a zero step (arithmetic.js).
  MAX_TICKS = 100_000

  class << self
    # getNiceTickValues: ticks that cover `min..max` and are round numbers. A single-value domain is centered in a few ticks; a
    # descending domain gives the ticks in descending order; an infinite bound gives ticks of that infinity.
    #
    # @api private
    # @param min [Numeric]
    # @param max [Numeric]
    # @param count [Integer] number of ticks wanted (at least 2 are returned for a real domain)
    # @param allow_decimals [Boolean] false rounds the step up to a whole number
    # @param mode [Symbol, String] :auto or :snap125
    # @return [Array<Float>]
    def values(min, max, count = 6, allow_decimals: true, mode: :auto)
      step_fn = step_function(mode)
      effective = [ count, 2 ].max
      low, high = [ min, max ].minmax
      return unbounded(min, max, low, high, count) if low == -Float::INFINITY || high == Float::INFINITY
      return single_value(low, count, allow_decimals) if low == high

      step, tick_min, tick_max = calculate_step(low, high, effective, allow_decimals, 0, step_fn)
      ticks = range_step(tick_min, tick_max + (Rational(1, 10) * step), step)
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
    def fixed_domain(min, max, count, allow_decimals: true, mode: :auto)
      step_fn = step_function(mode)
      low, high = [ min, max ].minmax
      return [ min.to_f, max.to_f ] if low == -Float::INFINITY || high == Float::INFINITY
      return [ low.to_f ] if low == high

      step = step_fn.call((decimal(high) - decimal(low)) / ([ count, 2 ].max - 1), allow_decimals, 0)
      ticks = range_step(decimal(low), decimal(high), step) + [ high.to_f ]
      ticks = ticks.map { |tick| Chadcn::Chart::Shape::Number.round_half_up(tick) } unless allow_decimals
      min > max ? ticks.reverse : ticks
    end

    private

    # The Rational of a number's shortest decimal form (decimal.js `new Decimal(number)`).
    def decimal(value)
      value.is_a?(Rational) ? value : Rational(value.to_s)
    end

    # decimal.js toNumber() round trip: the Rational of the nearest double.
    def through_float(value) = decimal(value.to_f)

    def step_function(mode)
      case mode.to_sym
      when :auto then method(:adaptive_step)
      when :snap125 then method(:snap125_step)
      else raise ArgumentError, "unknown nice ticks mode #{mode.inspect}, expected one of #{MODES.join(', ')}"
      end
    end

    # arithmetic.js getDigitCount: 1 for 0, 0 for [0.1, 1), -1 for [0.01, 0.1) ...
    def digit_count(value) = value.zero? ? 1 : Math.log10(value.to_f.abs).floor + 1

    # getAdaptiveStep: the rough step as a multiple of 0.05 (0.1 for one digit) of its order of magnitude, plus the correction.
    def adaptive_step(rough, allow_decimals, correction)
      return 0r if rough <= 0

      digits = digit_count(rough.to_f)
      magnitude = 10r**digits
      ratio_scale = digits == 1 ? Rational(1, 10) : Rational(5, 100)
      amended = (((rough / magnitude) / ratio_scale).to_f.ceil + correction) * ratio_scale
      step = amended * magnitude
      allow_decimals ? through_float(step) : Rational(step.to_f.ceil)
    end

    # getSnap125Step: the smallest of 1, 2, 2.5, 5 times a power of ten that is not below the rough step, moved up `correction` places.
    def snap125_step(rough, allow_decimals, correction)
      return 0r if rough <= 0

      magnitude = 10r**Math.log10(rough.to_f.abs).floor
      normalized = (rough / magnitude).to_f
      index = SNAP_STEPS.index { |nice| nice.to_f >= normalized - 1e-10 }
      if index.nil?
        magnitude *= 10
        index = 0
      end
      index += correction
      if index >= SNAP_STEPS.size
        magnitude *= 10r**(index / SNAP_STEPS.size)
        index %= SNAP_STEPS.size
      end
      step = SNAP_STEPS[index] * magnitude
      allow_decimals ? step : Rational(step.to_f.ceil)
    end

    # calculateStep: [step, first tick, last tick] with the number of ticks equal to `count`, 0 inside the ticks when the domain spans
    # it, retried with a larger step while the ticks would not fit.
    def calculate_step(min, max, count, allow_decimals, correction, step_fn)
      return [ 0r, 0r, 0r ] unless ((max.to_f - min.to_f) / (count - 1)).finite?

      step = step_fn.call((decimal(max) - decimal(min)) / (count - 1), allow_decimals, correction)
      middle = 0.between?(min, max) ? 0r : centre(decimal(min), decimal(max), step)
      below = ((middle - decimal(min)) / step).to_f.ceil
      above = ((decimal(max) - middle) / step).to_f.ceil
      needed = below + above + 1
      return calculate_step(min, max, count, allow_decimals, correction + 1, step_fn) if needed > count

      if needed < count
        max.positive? ? above += count - needed : below += count - needed
      end
      [ step, middle - (below * step), middle + (above * step) ]
    end

    # The midpoint minus its remainder modulo the step; decimal.js `mod` keeps the sign of the dividend, so it truncates toward zero.
    def centre(min, max, step)
      ((min + max) / 2 / step).truncate * step
    end

    # arithmetic.js rangeStep: start, start + step ... below `stop`.
    def range_step(start, stop, step)
      ticks = []
      current = start
      while current < stop && ticks.size < MAX_TICKS
        ticks << current.to_f
        current += step
      end
      ticks
    end

    # getTickOfSingleValue: `count` ticks around one value, 1 apart (a power of ten below 1 for a fraction below 1).
    def single_value(value, count, allow_decimals)
      step = 1r
      middle = decimal(value)
      if middle.denominator != 1 && allow_decimals
        if value.abs < 1
          step = 10r**(digit_count(value) - 1)
          middle = Rational((middle / step).to_f.floor) * step
        elsif value.abs > 1
          middle = Rational(value.floor)
        end
      elsif value.zero?
        middle = Rational((count - 1) / 2)
      elsif !allow_decimals
        middle = Rational(value.floor)
      end
      centre_index = (count - 1) / 2
      Array.new([ count, 0 ].max) { |i| (middle + ((i - centre_index) * step)).to_f }
    end

    # The branch of getNiceTickValues for an infinite bound.
    def unbounded(min, max, low, high, count)
      ticks = high == Float::INFINITY ? [ low.to_f ] + Array.new(count - 1, Float::INFINITY) : Array.new(count - 1, -Float::INFINITY) + [ high.to_f ]
      min > max ? ticks.reverse : ticks
    end
  end
end

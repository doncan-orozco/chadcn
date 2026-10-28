# frozen_string_literal: true

# The decimal arithmetic under the nice ticks (recharts util/scale/util/arithmetic.js over decimal.js-light): exact Rational values
# of the shortest decimal form of a Float, so 0.1 + 0.2 stays 0.3, and the tick walk built on them.
#
# @api private
module Chadcn::Chart::Scale::NiceTicks::Decimal
  # `rangeStep` stops here, as a guard against a zero step (arithmetic.js).
  MAX_TICKS = 100_000

  private_constant :MAX_TICKS

  class << self
    # The Rational of a number's shortest decimal form (decimal.js `new Decimal(number)`).
    #
    # @api private
    # @param value [Numeric]
    # @return [Rational]
    def exact(value) = value.is_a?(Rational) ? value : Rational(value.to_s)

    # decimal.js `toNumber()` round trip: the Rational of the nearest double.
    #
    # @api private
    # @param value [Numeric]
    # @return [Rational]
    def nearest_double(value) = exact(value.to_f)

    # The midpoint minus its remainder modulo the step; decimal.js `mod` keeps the sign of the dividend, so it truncates toward zero.
    #
    # @api private
    # @param min [Rational]
    # @param max [Rational]
    # @param step [Rational]
    # @return [Rational]
    def center(min, max, step) = ((min + max) / 2 / step).truncate * step

    # arithmetic.js `getDigitCount`: 1 for 0, 0 for [0.1, 1), -1 for [0.01, 0.1) ...
    #
    # @api private
    # @param value [Numeric]
    # @return [Integer]
    def digit_count(value) = value.zero? ? 1 : Math.log10(value.to_f.abs).floor + 1

    # arithmetic.js `rangeStep`: start, start + step ... below `stop`.
    #
    # @api private
    # @param start [Rational]
    # @param stop [Rational]
    # @param step [Rational]
    # @return [Array<Float>]
    def range_step(start, stop, step)
      ticks = []
      current = start
      while current < stop && ticks.size < MAX_TICKS
        ticks << current.to_f
        current += step
      end
      ticks
    end
  end
end

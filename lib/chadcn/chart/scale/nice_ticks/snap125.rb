# frozen_string_literal: true

# recharts' opt-in tick step (`getSnap125Step`): 1, 2, 2.5 or 5 times a power of ten.
#
# @api private
module Chadcn::Chart::Scale::NiceTicks::Snap125
  # The "nice" mantissas.
  NICE_STEPS = [ 1r, 2r, 5r / 2, 5r ].freeze
  # A mantissa this close below the rough step still counts as reaching it (float noise in the division).
  TOLERANCE = 1e-10

  private_constant :NICE_STEPS, :TOLERANCE

  class << self
    # The smallest of 1, 2, 2.5, 5 times a power of ten that is not below the rough step, moved up `correction` places.
    #
    # @api private
    # @param rough [Rational] the span divided by the intervals wanted
    # @param allow_decimals [Boolean] false rounds the step up to a whole number
    # @param correction [Integer] places moved up the list of nice steps to retry with a larger step
    # @return [Rational] 0 for a rough step that is not positive
    def step(rough, allow_decimals, correction)
      return 0r if rough <= 0

      magnitude = 10r**Math.log10(rough.to_f.abs).floor
      normalized = (rough / magnitude).to_f
      index = NICE_STEPS.index { |nice| nice.to_f >= normalized - TOLERANCE }
      if index.nil?
        magnitude *= 10
        index = 0
      end
      index += correction
      if index >= NICE_STEPS.size
        magnitude *= 10r**(index / NICE_STEPS.size)
        index %= NICE_STEPS.size
      end
      step = NICE_STEPS[index] * magnitude
      allow_decimals ? step : Rational(step.to_f.ceil)
    end
  end
end

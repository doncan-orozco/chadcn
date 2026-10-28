# frozen_string_literal: true

# recharts' default tick step (`getAdaptiveStep`): a multiple of 0.05 (0.1 for one digit) of the order of magnitude of the rough step.
#
# @api private
module Chadcn::Chart::Scale::NiceTicks::Adaptive
  Decimal = Chadcn::Chart::Scale::NiceTicks::Decimal

  private_constant :Decimal

  class << self
    # The rough step as a multiple of 0.05 (0.1 for one digit) of its order of magnitude, plus the correction.
    #
    # @api private
    # @param rough [Rational] the span divided by the intervals wanted
    # @param allow_decimals [Boolean] false rounds the step up to a whole number
    # @param correction [Integer] multiples of the ratio scale added to retry with a larger step
    # @return [Rational] 0 for a rough step that is not positive
    def step(rough, allow_decimals, correction)
      return 0r if rough <= 0

      digits = Decimal.digit_count(rough.to_f)
      magnitude = 10r**digits
      ratio_scale = digits == 1 ? Rational(1, 10) : Rational(5, 100)
      amended = (((rough / magnitude) / ratio_scale).to_f.ceil + correction) * ratio_scale
      step = amended * magnitude
      allow_decimals ? Decimal.nearest_double(step) : Rational(step.to_f.ceil)
    end
  end
end

# frozen_string_literal: true

# The few `Math` functions of JavaScript whose results differ from Ruby's (ties of `Math.round`, `floor` of an infinity, `log10` of a
# negative number), so the scales and the shapes that port d3 and recharts agree with them to the last digit. Named after the
# JavaScript functions they reproduce.
#
# @api private
module Chadcn::Chart::JsMath
  class << self
    # `Math.round(value)`: the nearest integer with ties rounded toward +Infinity (so -2.5 becomes -2). Non-finite values are
    # returned unchanged, as JavaScript does.
    #
    # @api private
    # @param value [Numeric]
    # @return [Float]
    def round(value)
      float = value.to_f
      return float unless float.finite?

      floor = float.floor
      (float - floor >= 0.5 ? floor + 1 : floor).to_f
    end

    # `Math.floor(value)`: infinities and NaN pass through instead of raising.
    #
    # @api private
    # @param value [Float]
    # @return [Float]
    def floor(value) = value.finite? ? value.floor.to_f : value

    # `Math.ceil(value)`: infinities and NaN pass through instead of raising.
    #
    # @api private
    # @param value [Float]
    # @return [Float]
    def ceil(value) = value.finite? ? value.ceil.to_f : value

    # `Math.log10(value)`: NaN below zero (Ruby raises), -Infinity at zero.
    #
    # @api private
    # @param value [Float]
    # @return [Float]
    def log10(value) = value.negative? ? Float::NAN : Math.log10(value)
  end
end

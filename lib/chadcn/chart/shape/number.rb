# frozen_string_literal: true

# Number formatting and rounding with JavaScript semantics, so the path strings the chart math emits equal the ones React DOM prints.
# Every shape formats its numbers through here.
#
# @api private
module Chadcn::Chart::Shape::Number
  # Largest magnitude JavaScript prints without an exponent (Number::toString, ECMA-262 6.1.6.1.20).
  EXPONENT_LIMIT = 21
  # Smallest decimal exponent JavaScript prints without an exponent form (0.000001 is positional, 1e-7 is not).
  EXPONENT_FLOOR = -6

  # Parses Ruby's shortest round-trip representation, e.g. "1.0e-07", "123.456", "-0.001".
  FLOAT_PARTS = /\A(?<sign>-?)(?<int>\d+)(?:\.(?<frac>\d+))?(?:e(?<exp>[+-]?\d+))?\z/

  class << self
    # JavaScript `Number#toString` of a Numeric (radix 10): shortest round-trip digits, `-0` printed as "0", exponent form
    # (`1e-7`, `1e+21`) outside 1e-6...1e21, "NaN" and "Infinity" spelled as JavaScript does.
    #
    # @api private
    # @param value [Numeric]
    # @return [String]
    def format(value)
      return value.to_s if value.is_a?(Integer) && value.abs < 10**EXPONENT_LIMIT

      float = value.to_f
      return "NaN" if float.nan?
      return float.positive? ? "Infinity" : "-Infinity" if float.infinite?
      return "0" if float.zero?

      format_finite(float)
    end

    # `Math.round(value)`: the nearest integer with ties rounded toward +Infinity (so -2.5 becomes -2). Non-finite values are
    # returned unchanged, as JavaScript does.
    #
    # @api private
    # @param value [Numeric]
    # @return [Float]
    def round_half_up(value)
      float = value.to_f
      return float unless float.finite?

      floor = float.floor
      (float - floor >= 0.5 ? floor + 1 : floor).to_f
    end

    # `Math.round(value * 10**digits) / 10**digits` (d3-path `digits`, recharts util/round.js), with `-0` normalized to `0`.
    #
    # @api private
    # @param value [Numeric]
    # @param digits [Integer] decimals kept
    # @return [Float]
    def round(value, digits)
      factor = 10.0**digits
      rounded = round_half_up(value * factor) / factor
      rounded.zero? ? 0.0 : rounded
    end

    private

    def format_finite(float)
      match = FLOAT_PARTS.match(float.to_s) or raise ArgumentError, "unexpected float representation #{float.to_s.inspect}"
      int = match[:int]
      frac = match[:frac].to_s
      all = int + frac
      leading = all[/\A0*/].size
      digits = all.sub(/\A0+/, "").sub(/0+\z/, "")
      # n: position of the decimal point relative to the first significant digit (ECMA-262 notation).
      point = int.size - leading + match[:exp].to_i
      "#{match[:sign]}#{layout(digits, point)}"
    end

    def layout(digits, point)
      count = digits.size
      if point.between?(count, EXPONENT_LIMIT)
        digits + ("0" * (point - count))
      elsif point.positive? && point <= EXPONENT_LIMIT
        "#{digits[0, point]}.#{digits[point..]}"
      elsif point <= 0 && point > EXPONENT_FLOOR
        "0.#{'0' * -point}#{digits}"
      else
        exponent = point - 1
        mantissa = count == 1 ? digits : "#{digits[0]}.#{digits[1..]}"
        "#{mantissa}e#{exponent.negative? ? '-' : '+'}#{exponent.abs}"
      end
    end
  end
end

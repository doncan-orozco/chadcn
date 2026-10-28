# frozen_string_literal: true

# Reading and coercing chart data the way recharts does (util/ChartUtils.js `getValueByDataKey`, util/DataUtils.js): a data key is a
# Symbol or String looked up in a row Hash (either spelling of the key), or a callable that receives the row; numbers are Floats so no
# arithmetic is integer division.
#
# @api private
module Chadcn::Chart::Cartesian::Value
  # What JavaScript `Number(string)` accepts as a finite decimal (hex, `Infinity` and the like are not data).
  DECIMAL_TEXT = /\A[+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?\z/i

  private_constant :DECIMAL_TEXT

  class << self
    # `getValueByDataKey(row, key)`.
    #
    # @api private
    # @param row [Hash, nil]
    # @param key [Symbol, String, #call, nil]
    # @return [Object, nil]
    def read(row, key)
      return key.call(row) if key.respond_to?(:call)
      return unless row.respond_to?(:key?) && !key.nil?

      [ key, key.to_s, (key.to_sym if key.respond_to?(:to_sym)) ].each { |spelling| return row[spelling] if row.key?(spelling) }
      nil
    end

    # `makeNumber`: a finite number from a number or a numeric string, nil for anything else.
    #
    # @api private
    # @param value [Object]
    # @return [Float, nil]
    def number(value)
      case value
      when Numeric then value.real? && value.to_f.finite? ? value.to_f : nil
      when String then numeric_text(value)
      end
    end

    # `isNumber`: a Numeric that is not NaN (infinities count).
    #
    # @api private
    # @param value [Object]
    # @return [Boolean]
    def numeric?(value) = value.is_a?(Numeric) && value.real? && !value.to_f.nan?

    # `String(value)` as a tick label shows it: JavaScript number formatting for numbers, "" for nil.
    #
    # @api private
    # @param value [Object]
    # @return [String]
    def text(value)
      case value
      when nil then ""
      when Numeric then Chadcn::Chart::Shape::Number.format(value)
      else value.to_s
      end
    end

    # `getPercentValue(percent, total, default, validate)`: a number, a numeric string, or a percent string of `total`.
    #
    # @api private
    # @param percent [Numeric, String, nil]
    # @param total [Numeric, nil]
    # @param default [Float]
    # @param validate [Boolean] cap the result at `total`
    # @return [Float]
    def percent(percent, total, default = 0.0, validate: false)
      return default unless percent.is_a?(Numeric) || percent.is_a?(String)

      value = if percent.is_a?(String) && percent.end_with?("%")
        return default if total.nil?

        total * percent.to_f / 100
      else
        percent.is_a?(String) ? (numeric_text(percent) || Float::NAN) : percent.to_f
      end
      value = default if value.nan?
      value = total if validate && !total.nil? && value > total
      value
    end

    private

    def numeric_text(text)
      stripped = text.strip
      return 0.0 if stripped.empty?

      DECIMAL_TEXT.match?(stripped) ? stripped.to_f : nil
    end
  end
end

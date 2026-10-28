# frozen_string_literal: true

# The formatters a chart accepts (`tick_formatter:`, `formatter:`, `label_formatter:`): any callable, or one of the named formatters
# that scenarios and JSON can carry because they hold no code (dev/port/specs/chart.md, "Named formatters"): `{ slice: [start, stop] }`
# (JavaScript `String(value).slice(start, stop)`), `:locale` (`Number(value).toLocaleString("en-US")`) and `:percent`
# (`(Number(value) * 100).toLocaleString("en-US") + "%"`).
#
# @api private
module Chadcn::Chart::Cartesian::Formatter
  class << self
    # @api private
    # @param formatter [#call, Hash, Symbol, String, nil] a callable, `{ slice: [start, stop] }`, `:locale` or `:percent`
    # @return [#call, nil] a callable taking the value (and the index), or nil when there is no formatter
    # @raise [ArgumentError] on a formatter that is none of the above
    def resolve(formatter)
      case formatter
      when nil then nil
      when Hash then hash_formatter(formatter)
      when Symbol, String then named(formatter)
      else
        return formatter if formatter.respond_to?(:call)

        raise ArgumentError, "a formatter must be callable or a named formatter (got #{formatter.inspect})"
      end
    end

    # `String(value).slice(start, stop)` with JavaScript's clamping (BMP text).
    #
    # @api private
    # @param value [Object]
    # @param start [Integer]
    # @param stop [Integer, nil] exclusive; nil is the end
    # @return [String]
    def slice(value, start, stop = nil)
      text = Chadcn::Chart::Cartesian::Value.text(value)
      length = text.length
      from = clamp_index(start, length)
      to = stop.nil? ? length : clamp_index(stop, length)
      to > from ? text[from...to] : ""
    end

    # `Number(value).toLocaleString("en-US")`: comma grouping, at most three fraction digits (half away from zero); a value that is not a
    # number is returned as `String(value)`.
    #
    # @api private
    # @param value [Object]
    # @return [String]
    def locale(value)
      number = Chadcn::Chart::Cartesian::Value.number(value)
      return Chadcn::Chart::Cartesian::Value.text(value) if number.nil?

      whole, fraction = (exact(number).abs * 1000).round(half: :up).divmod(1000)
      sign = number.negative? || (number.zero? && (1.0 / number).negative?) ? "-" : ""
      grouped = whole.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, ",")
      suffix = fraction.zero? ? "" : ".#{format('%03d', fraction).sub(/0+\z/, '')}"
      "#{sign}#{grouped}#{suffix}"
    end

    # `(Number(value) * 100).toLocaleString("en-US") + "%"`.
    #
    # @api private
    # @param value [Object]
    # @return [String]
    def percent(value)
      number = Chadcn::Chart::Cartesian::Value.number(value)
      number.nil? ? Chadcn::Chart::Cartesian::Value.text(value) : "#{locale(number * 100)}%"
    end

    private

    def named(name)
      case name.to_sym
      when :locale then ->(value, *) { locale(value) }
      when :percent then ->(value, *) { percent(value) }
      else raise ArgumentError, "unknown formatter #{name.inspect}, expected a callable, { slice: [start, stop] }, :locale or :percent"
      end
    end

    def hash_formatter(formatter)
      name, args = formatter.to_a.first
      valid = formatter.size == 1 && name.to_s == "slice" && args.is_a?(Array) && args.size.between?(1, 2)
      raise ArgumentError, "unknown formatter #{formatter.inspect}" unless valid

      ->(value, *) { slice(value, *args) }
    end

    def clamp_index(index, length) = index.negative? ? [ length + index, 0 ].max : [ index, length ].min

    # The decimal ICU sees: floats by their shortest representation.
    def exact(number) = Rational(number.to_s)
  end
end

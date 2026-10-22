# frozen_string_literal: true

require "date"

# Date coercion for Calendar: every date reaches the controller as an ISO `YYYY-MM-DD` string. The controller parses it as a LOCAL
# date, so a date never shifts with the time zone.
#
# @api private
module Chadcn::Calendar::Dates
  # Shape of an ISO calendar date.
  ISO = /\A\d{4}-\d{2}-\d{2}\z/

  # Matcher keys (any spelling) => the key the controller reads.
  MATCHER_KEYS = { "from" => "from", "to" => "to", "before" => "before", "after" => "after", "day_of_week" => "dayOfWeek", "dayofweek" => "dayOfWeek" }.freeze

  module_function

  # @param value [Date, Time, DateTime, String] a date, or an ISO `YYYY-MM-DD` string
  # @param name [String] the option name, for the error message
  # @return [Date]
  # @raise [ArgumentError] when the value is not a date
  def to_date(value, name = "date")
    case value
    when DateTime, Time then value.to_date
    when Date then value
    when String
      raise ArgumentError, "#{name} must be a Date or an ISO YYYY-MM-DD string, got #{value.inspect}" unless ISO.match?(value)

      Date.iso8601(value)
    else
      raise ArgumentError, "#{name} must be a Date or an ISO YYYY-MM-DD string, got #{value.inspect}"
    end
  rescue Date::Error
    raise ArgumentError, "#{name} is not a valid date: #{value.inspect}"
  end

  # @return [String, nil] `YYYY-MM-DD`, nil for nil
  def iso(value, name = "date")
    to_date(value, name).iso8601 unless value.nil?
  end

  # @return [String, nil] the first day of the date's month as `YYYY-MM-DD`, nil for nil
  def first_of_month(value, name = "month")
    return if value.nil?

    date = to_date(value, name)
    Date.new(date.year, date.month, 1).iso8601
  end

  # A `{ from:, to: }` selection: String or Symbol keys, `to` optional.
  #
  # @return [Hash{String => String, nil}, nil]
  def range(value, name = "selected")
    return if value.nil?
    raise ArgumentError, "#{name} must be a Hash with :from and :to for mode range, got #{value.inspect}" unless value.is_a?(Hash)

    pairs = value.transform_keys(&:to_s)
    unknown = pairs.keys - %w[from to]
    raise ArgumentError, "#{name} accepts only :from and :to, got #{unknown.join(', ')}" unless unknown.empty?

    { "from" => iso(pairs["from"], "#{name}[:from]"), "to" => iso(pairs["to"], "#{name}[:to]") }
  end

  # Normalizes a matcher (`disabled`, `hidden`, a `modifiers` value) to its JSON form: booleans stay, dates become ISO strings,
  # hashes keep `from`/`to`/`before`/`after`/`dayOfWeek` (a missing side of a range stays present as nil: the controller tells a range from a
  # one-sided matcher by the key), arrays are normalized element by element.
  #
  # @raise [ArgumentError] for procs (functions are not portable) and anything that is not a matcher
  def matcher(value, name = "matcher")
    case value
    when true, false then value
    when Proc, Method then raise ArgumentError, "#{name}: functions are not portable, pass dates, ranges, { day_of_week: }, { before:, after: } or booleans"
    when Array then value.map { |element| matcher(element, name) }
    when Hash then matcher_hash(value, name)
    else iso(value, name)
    end
  end

  # @return [Hash] the matcher hash with normalized keys and ISO dates
  def matcher_hash(value, name)
    result = value.each_with_object({}) do |(key, element), hash|
      normalized = MATCHER_KEYS[key.to_s.gsub(/([a-z])([A-Z])/, '\1_\2').downcase]
      raise ArgumentError, "#{name}: unknown matcher key #{key.inspect}" unless normalized

      hash[normalized] = normalized == "dayOfWeek" ? day_of_week(element, name) : iso(element, "#{name}[#{key}]")
    end
    result["to"] = nil if result.key?("from") && !result.key?("to")
    result["from"] = nil if result.key?("to") && !result.key?("from")
    result
  end

  # @return [Integer, Array<Integer>] weekday numbers, 0 = Sunday
  def day_of_week(value, name)
    days = Array(value)
    raise ArgumentError, "#{name}: day_of_week takes integers 0..6" unless days.all? { |day| day.is_a?(Integer) && day.between?(0, 6) }

    value.is_a?(Array) ? days : days.first
  end
end

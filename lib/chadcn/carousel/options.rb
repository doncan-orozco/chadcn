# frozen_string_literal: true

# The embla option schema of a {Chadcn::Carousel}: normalizes the caller's `opts:` (symbol or string keys, snake_case or camelCase)
# to the camelCase JSON the controller reads, and raises `ArgumentError` for a value embla's types would reject. A plain object,
# not a `Chadcn::Base` part, so no yielded-root helper is generated for it.
#
# @api private
class Chadcn::Carousel::Options
  # Enumerated embla options (the TS unions); other values raise like a type error would.
  ENUM_OPTIONS = {
    "align" => %w[start center end],
    "containScroll" => [ "trimSnaps", "keepSnaps", false ].freeze,
    "direction" => %w[ltr rtl]
  }.freeze
  BOOLEAN_OPTIONS = %w[active watchDrag watchResize watchSlides watchFocus loop dragFree skipSnaps].freeze
  private_constant :ENUM_OPTIONS, :BOOLEAN_OPTIONS

  # @param opts [Hash, nil]
  # @return [Hash{String => Object}] camelCase keys, symbol values turned into strings
  # @raise [ArgumentError] when `opts` is not a Hash or a value is invalid
  def self.normalize(opts)
    return {} if opts.nil?
    raise ArgumentError, "opts: must be a Hash (got #{opts.class})" unless opts.is_a?(Hash)

    opts.each_with_object({}) do |(key, value), out|
      name = to_camel(key)
      out[name] = option_value(name, value)
    end
  end

  def self.to_camel(key) = key.to_s.gsub(/_([a-z])/) { Regexp.last_match(1).upcase }

  def self.option_value(name, value)
    value = value.name if value.is_a?(Symbol)
    return value.to_h { |query, nested| [ query.to_s, normalize(nested) ] } if name == "breakpoints" && value.is_a?(Hash)

    validate(name, value)
    value
  end

  def self.validate(name, value)
    allowed = ENUM_OPTIONS[name]
    raise ArgumentError, "opts #{name}: #{value.inspect} is not one of #{allowed.inspect}" if allowed && !allowed.include?(value)
    raise ArgumentError, "opts #{name}: must be true or false (got #{value.inspect})" if BOOLEAN_OPTIONS.include?(name) && ![ true, false ].include?(value)
    return unless name == "slidesToScroll" && !(value.is_a?(Integer) && value.positive?) && value != "auto"

    raise ArgumentError, "opts slidesToScroll: must be a positive Integer or \"auto\" (got #{value.inspect})"
  end
  private_class_method :to_camel, :option_value, :validate
end

# frozen_string_literal: true

# shadcn Carousel over embla-carousel. Spec: dev/port/specs/carousel.md.
# Behavior: controllers/chadcn/carousel_controller.js (an embla-compatible engine, positioned with transforms).
#
# Root of the carousel. Yields itself, so `content`, `item`, `previous` and `next` are yielded-root helpers equal to rendering
# `Carousel::Content`, `Carousel::Item`, `Carousel::Previous` and `Carousel::Next`.
#
# @example
#   render Chadcn::Carousel.new(class: "w-full max-w-xs") do |carousel|
#     carousel.content do
#       carousel.item { "1" }
#       carousel.item { "2" }
#     end
#     carousel.previous
#     carousel.next
#   end
class Chadcn::Carousel < Chadcn::Base
  # @api private
  ROOT_KEY = :shadcn_carousel_root

  ORIENTATIONS = %w[horizontal vertical].freeze

  # Enumerated embla options (the TS unions); other values raise like a type error would.
  ENUM_OPTIONS = {
    "align" => %w[start center end],
    "containScroll" => [ "trimSnaps", "keepSnaps", false ].freeze,
    "direction" => %w[ltr rtl]
  }.freeze
  BOOLEAN_OPTIONS = %w[active watchDrag watchResize watchSlides watchFocus loop dragFree skipSnaps].freeze
  private_constant :ENUM_OPTIONS, :BOOLEAN_OPTIONS

  # @param orientation [String, Symbol] "horizontal" or "vertical"
  # @param opts [Hash, nil] embla options (symbol or string keys, snake_case or camelCase); `axis` is derived from `orientation`
  # @param plugins [nil] not supported (JS plugin objects); any other value raises
  # @param set_api [nil] not supported (a JS callback); use the controller's `api` and the `chadcn--carousel:*` events
  # @param attrs [Hash] HTML attributes merged onto the root element
  # @raise [ArgumentError] for an unknown orientation or option value, or a `plugins:` / `set_api:` value
  def initialize(orientation: "horizontal", opts: nil, plugins: nil, set_api: nil, **attrs)
    { plugins:, set_api: }.each do |name, value|
      raise ArgumentError, "#{name}: is a React-only value, use the controller api and the chadcn--carousel:* events" unless value.nil?
    end

    @orientation = normalize_option(orientation)
    raise ArgumentError, "unknown orientation: #{orientation.inspect} (expected horizontal or vertical)" unless ORIENTATIONS.include?(@orientation)

    @opts = normalize_opts(opts)
    @attrs = attrs
    super()
  end

  # @yieldparam carousel [Chadcn::Carousel] the root, exposing the part helpers
  # @return [void]
  def view_template
    previous = context[ROOT_KEY]
    context[ROOT_KEY] = { orientation: @orientation }
    attrs = merge_attrs({
                          class: "relative", role: "region", aria: { roledescription: "carousel" },
                          data: {
                            slot: "carousel", controller: "chadcn--carousel",
                            action: "keydown->chadcn--carousel#keydown:capture",
                            chadcn__carousel_orientation_value: @orientation,
                            chadcn__carousel_opts_value: json(@opts)
                          }
                        }, @attrs)
    div(**attrs) { yield self if block_given? }
  ensure
    context[ROOT_KEY] = previous
  end

  private

  def normalize_opts(opts)
    return {} if opts.nil?
    raise ArgumentError, "opts: must be a Hash (got #{opts.class})" unless opts.is_a?(Hash)

    opts.each_with_object({}) do |(key, value), out|
      name = camelize(key)
      out[name] = option_value(name, value)
    end
  end

  def camelize(key) = key.to_s.gsub(/_([a-z])/) { Regexp.last_match(1).upcase }

  def option_value(name, value)
    value = value.name if value.is_a?(Symbol)
    return value.to_h { |query, nested| [ query.to_s, normalize_opts(nested) ] } if name == "breakpoints" && value.is_a?(Hash)

    validate_option(name, value)
    value
  end

  def validate_option(name, value)
    allowed = ENUM_OPTIONS[name]
    raise ArgumentError, "opts #{name}: #{value.inspect} is not one of #{allowed.inspect}" if allowed && !allowed.include?(value)
    raise ArgumentError, "opts #{name}: must be true or false (got #{value.inspect})" if BOOLEAN_OPTIONS.include?(name) && ![ true, false ].include?(value)
    return unless name == "slidesToScroll" && !(value.is_a?(Integer) && value.positive?) && value != "auto"

    raise ArgumentError, "opts slidesToScroll: must be a positive Integer or \"auto\" (got #{value.inspect})"
  end
end

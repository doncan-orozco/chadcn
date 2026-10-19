# frozen_string_literal: true

# shadcn Slider over Radix Slider (Root, Track, Range, Thumb rendered internally). Spec: docs/shadcn-port/specs/slider.md.
# Behavior: controllers/shadcn/slider_controller.js (one controller on the root span).
using Phlex::Shadcn::Values::Refinements

# Single component with no nested parts: the track, range, thumbs and hidden inputs (one per thumb) are rendered internally.
# One thumb per element of the initial value array. With no array value, two thumbs and two hidden inputs are rendered:
# the first at `min`, the second hidden (no `aria-valuenow`, no input value).
#
# Controlled mode: `value:` is controlled only when it is an Array (`value.is_a?(Array)`); any other value is ignored
# and the slider is uncontrolled. A controlled slider only dispatches events on user input and the caller re-renders.
# Events: `shadcn--slider:value-change` (user input, and a form reset that changes the values) and
# `shadcn--slider:value-commit` (a finished drag and keyboard steps), both with `detail: { value }`.
# The hidden inputs are removed by the controller when the slider is neither inside a `<form>` nor given `form:`.
#
# @example
#   render Phlex::Shadcn::Slider.new(default_value: [ 25, 75 ], max: 100, step: 5, name: "price", class: "w-64")
class Phlex::Shadcn::Slider < Phlex::Shadcn::Base
  include Phlex::Shadcn::Direction::Consumer

  # Allowed values of `orientation:`.
  # @return [Array<String>]
  ORIENTATIONS = %w[horizontal vertical].freeze
  # Allowed values of `dir:`.
  # @return [Array<String>]
  DIRECTIONS = %w[ltr rtl].freeze
  # Classes of the root span.
  #
  # @api private
  ROOT_CLASS = "relative flex w-full touch-none items-center select-none data-[disabled]:opacity-50 data-[orientation=vertical]:h-full data-[orientation=vertical]:min-h-44 data-[orientation=vertical]:w-auto data-[orientation=vertical]:flex-col"
  # Classes of the track span.
  #
  # @api private
  TRACK_CLASS = "relative grow overflow-hidden rounded-full bg-muted data-[orientation=horizontal]:h-1.5 data-[orientation=horizontal]:w-full data-[orientation=vertical]:h-full data-[orientation=vertical]:w-1.5"
  # Classes of the filled range span.
  #
  # @api private
  RANGE_CLASS = "absolute bg-primary data-[orientation=horizontal]:h-full data-[orientation=vertical]:w-full"
  # Classes of each thumb.
  #
  # @api private
  THUMB_CLASS = "block size-4 shrink-0 rounded-full border border-primary bg-white shadow-sm ring-ring/50 transition-[color,box-shadow] hover:ring-4 focus-visible:ring-4 focus-visible:outline-hidden disabled:pointer-events-none disabled:opacity-50"
  # Per-orientation transform exposed as `--radix-slider-thumb-transform`.
  # @return [Hash{String => String}]
  THUMB_TRANSFORM = { "horizontal" => "translateX(-50%)", "vertical" => "translateY(50%)" }.freeze

  # @param default_value [Array<Numeric>, nil] initial thumb values (uncontrolled); without it the slider renders two
  #   thumbs and two hidden inputs, the first at `min` and the second hidden (no `aria-valuenow`, no input value)
  # @param value [Array<Numeric>, nil] controlled thumb values: an Array makes the slider controlled; any other value is
  #   ignored and the slider is uncontrolled
  # @param min [Numeric] lowest value (default 0)
  # @param max [Numeric] highest value (default 100)
  # @param step [Numeric] value increment (default 1)
  # @param orientation [String, Symbol] one of {ORIENTATIONS} (default "horizontal")
  # @param disabled [Boolean] disables the slider (default false)
  # @param inverted [Boolean] reverses the direction of the range
  # @param min_steps_between_thumbs [Integer] minimum distance between thumbs, in steps
  # @param preserve_thumb_order [Boolean] stops a dragged thumb from passing its neighbours (the controller always
  #   keeps the values sorted)
  # @param name [String, nil] form field name of the hidden inputs; `name[]` is used when more than one value is present,
  #   so without `value:`/`default_value:` (two thumb elements, one value) the name stays `name`
  # @param form [String, nil] id of the associated `<form>`
  # @param dir [String, Symbol, nil] one of {DIRECTIONS}; the surrounding direction provider's direction is the default for horizontal sliders only
  # @param min_label [String] `aria-label` of the first thumb of a two-thumb slider (default: "Minimum")
  # @param max_label [String] `aria-label` of the second thumb of a two-thumb slider (default: "Maximum")
  # @param value_label [String] `format` template of the thumb `aria-label` with more than two thumbs; `%<index>d` is the
  #   1-based position and `%<count>d` the number of thumbs (default: "Value %<index>d of %<count>d")
  # @param attrs [Hash] HTML attributes for the root span (`class:` merged last, `aria:`, `data:`, `style:`)
  # @raise [ArgumentError] when `orientation:` or `dir:` is not an allowed value
  def initialize(default_value: nil, value: nil, min: 0, max: 100, step: 1, orientation: "horizontal", disabled: false,
                 inverted: false, min_steps_between_thumbs: 0, preserve_thumb_order: false, name: nil, form: nil,
                 dir: nil, min_label: "Minimum", max_label: "Maximum", value_label: "Value %<index>d of %<count>d", **attrs)
    @controlled = value.is_a?(Array)
    @min = min
    @max = max
    @step = step
    @orientation = choice(orientation, ORIENTATIONS, "orientation") || "horizontal"
    @disabled = disabled
    @inverted = inverted
    @min_steps = min_steps_between_thumbs
    @preserve_order = preserve_thumb_order
    @name = name
    @form = form
    @dir = choice(dir, DIRECTIONS, "dir")
    @values = (@controlled ? value : default_value) || [ min ]
    initial = [ value, default_value ].find { |candidate| candidate.is_a?(Array) } || [ min, max ]
    @thumb_count = initial.length
    @min_label = min_label
    @max_label = max_label
    @value_label = value_label
    @attrs = attrs
    super()
  end

  # @return [void]
  def view_template
    @horizontal = @orientation == "horizontal"
    @direction = use_direction(@dir) if @horizontal
    @from_start = @horizontal ? (@direction == "ltr") != @inverted : !@inverted
    span(**merge_attrs(root_defaults, @attrs.except(:style))) do
      span(data: { orientation: @orientation, disabled: disabled_data, slot: "slider-track" }, class: TRACK_CLASS) do
        span(data: { orientation: @orientation, disabled: disabled_data, slot: "slider-range" }, class: RANGE_CLASS, style: range_style)
      end
      @thumb_count.times { |index| thumb(index) }
    end
  end

  private

  def choice(value, allowed, name)
    return if value.nil?

    value = value.to_s
    return value if allowed.include?(value)

    raise ArgumentError, "#{name} must be one of #{allowed.join(', ')}, got #{value.inspect}"
  end

  def disabled_data = (@disabled ? "" : nil)

  def start_edge
    if @horizontal
      @from_start ? "left" : "right"
    else
      (@from_start ? "bottom" : "top")
    end
  end

  def end_edge
    if @horizontal
      @from_start ? "right" : "left"
    else
      (@from_start ? "top" : "bottom")
    end
  end

  def root_defaults
    {
      aria: { disabled: @disabled.to_s },
      dir: (@horizontal ? @direction : @dir),
      style: [ style_string(@attrs[:style]).unless_blank,
               "--radix-slider-thumb-transform: #{THUMB_TRANSFORM[@orientation]};" ].compact.join("; "),
      class: ROOT_CLASS,
      data: {
        slot: "slider", orientation: @orientation, disabled: disabled_data, controller: "shadcn--slider",
        shadcn__slider_min_value: js(@min), shadcn__slider_max_value: js(@max), shadcn__slider_step_value: js(@step),
        shadcn__slider_orientation_value: @orientation, shadcn__slider_inverted_value: @inverted.to_s,
        shadcn__slider_disabled_value: @disabled.to_s, shadcn__slider_controlled_value: @controlled.to_s,
        shadcn__slider_min_steps_between_thumbs_value: js(@min_steps), shadcn__slider_preserve_thumb_order_value: @preserve_order.to_s,
        shadcn__slider_form_value: @form
      }
    }
  end

  def thumb(index)
    value = @values[index]
    percent = value.nil? ? 0 : percentage(value)
    span(style: "transform: var(--radix-slider-thumb-transform); position: absolute; #{start_edge}: calc(#{js(percent)}% + 0px);") do
      span(**thumb_attrs(index, value))
    end
    input(style: "display: none;", name: input_name, form: @form, value: (js(value) unless value.nil?))
  end

  def thumb_attrs(index, value)
    {
      role: "slider",
      aria: { label: thumb_label(index), valuemin: js(@min), valuenow: (js(value) unless value.nil?), valuemax: js(@max),
              orientation: @orientation },
      data: { orientation: @orientation, disabled: disabled_data, slot: "slider-thumb", radix_collection_item: "" },
      tabindex: (@disabled ? nil : 0),
      style: (value.nil? ? "display: none;" : nil),
      class: THUMB_CLASS
    }
  end

  def input_name
    return unless @name

    "#{@name}#{'[]' if @values.length > 1}"
  end

  def thumb_label(index)
    case @values.length
    when 0, 1 then nil
    when 2 then [ @min_label, @max_label ][index]
    else Kernel.format(@value_label, index: index + 1, count: @values.length)
    end
  end

  def range_style
    percents = @values.map { |value| percentage(value) }
    start = percents.length > 1 ? percents.min : 0
    "#{start_edge}: #{js(start)}%; #{end_edge}: #{js(100 - percents.max)}%;"
  end

  # Same float operation order as Radix convertValueToPercentage.
  def percentage(value)
    (100.0 / (@max - @min) * (value - @min)).clamp(0, 100)
  end

  # JS Number#toString: whole floats without the fraction.
  def js(number)
    number.is_a?(Float) && number.finite? && number == number.floor ? number.to_i.to_s : number.to_s
  end
end

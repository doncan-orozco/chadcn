# frozen_string_literal: true

# shadcn Toggle over Radix Toggle. Spec: docs/shadcn-port/specs/toggle.md
using Phlex::Shadcn::Values::Refinements

# A two-state button (`aria-pressed`). Use `Toggle.variants` to get its classes for another element.
#
# @example
#   render Phlex::Shadcn::Toggle.new(variant: :outline, size: :sm, aria: { label: "Bold" }) { "B" }
class Phlex::Shadcn::Toggle < Phlex::Shadcn::Base
  # Base classes shared by every variant and size.
  #
  # @return [String]
  BASE = "inline-flex items-center justify-center gap-2 rounded-md text-sm font-medium whitespace-nowrap transition-[color,box-shadow] outline-none hover:bg-muted hover:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 data-[state=on]:bg-accent data-[state=on]:text-accent-foreground dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"

  # Classes per `variant:` name.
  #
  # @return [Hash{String => String}]
  VARIANTS = {
    "default" => "bg-transparent",
    "outline" => "border border-input bg-transparent shadow-xs hover:bg-accent hover:text-accent-foreground"
  }.freeze

  # Classes per `size:` name.
  #
  # @return [Hash{String => String}]
  SIZES = {
    "default" => "h-9 min-w-9 px-2",
    "sm" => "h-8 min-w-8 px-1.5",
    "lg" => "h-10 min-w-10 px-2.5"
  }.freeze

  # React `toggleVariants`: the class string of a toggle without rendering it.
  #
  # @param variant [String, Symbol, nil] a key of {VARIANTS}; underscores are normalized to dashes, nil means "default"
  # @param size [String, Symbol, nil] a key of {SIZES}; underscores are normalized to dashes, nil means "default"
  # @param class [String, nil] extra classes merged last
  # @return [String]
  # @raise [ArgumentError] on an unknown variant or size
  # @example
  #   Phlex::Shadcn::Toggle.variants(variant: :outline, size: :lg)
  def self.variants(variant: "default", size: "default", class: nil)
    new(variant:, size:).send(:classes, binding.local_variable_get(:class))
  end

  # @param variant [String, Symbol, nil] a key of {VARIANTS}; underscores are normalized to dashes, nil means "default"
  # @param size [String, Symbol, nil] a key of {SIZES}; underscores are normalized to dashes, nil means "default"
  # @param pressed [Boolean, nil] controlled state (non-nil: user input only dispatches an event, the caller re-renders)
  # @param default_pressed [Boolean] initial state (uncontrolled)
  # @param disabled [Boolean] disables the button (`disabled` attribute and `data-disabled`)
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base]
  #   a tag or component instance to render instead of the `<button>`; false renders the default element
  # @param attrs [Hash] HTML attributes for the root (`class:` merged last, `aria:`, `data:`)
  # @raise [ArgumentError] on an unknown variant or size
  def initialize(variant: "default", size: "default", pressed: nil, default_pressed: false, disabled: false, as_child: false, **attrs)
    @variant = normalize_option(variant) || "default"
    @size = normalize_option(size) || "default"
    raise ArgumentError, "unknown variant: #{variant.inspect} (expected one of #{VARIANTS.keys.join(', ')})" unless VARIANTS.key?(@variant)
    raise ArgumentError, "unknown size: #{size.inspect} (expected one of #{SIZES.keys.join(', ')})" unless SIZES.key?(@size)

    @controlled = !pressed.nil?
    @pressed = @controlled ? pressed : default_pressed
    @disabled = disabled
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the toggle content
  # @return [void]
  def view_template(&)
    attrs = merge_attrs(root_attrs, @attrs.except(:class))
    attrs = attrs.merge(class: [ @slot_class, classes(@attrs[:class]) ].reject_blank.join(" "))
    attrs = with_action(attrs)
    return render_as_child(@as_child, **attrs, &) if @as_child

    button(**attrs, &)
  end

  private

  def classes(extra) = cn(BASE, VARIANTS[@variant], SIZES[@size], extra)

  def root_attrs
    {
      type: "button",
      aria: { pressed: @pressed },
      data: { state: @pressed ? "on" : "off", slot: "toggle", controller: "shadcn--toggle",
              shadcn__toggle_controlled_value: @controlled, shadcn__toggle_disabled_value: @disabled,
              **(@disabled ? { disabled: "" } : {}) },
      disabled: @disabled
    }
  end

  # Radix runs the consumer onClick first, then the toggle: our action goes last.
  def with_action(attrs)
    action = [ attrs.dig(:data, :action), "click->shadcn--toggle#toggle" ].reject_blank.join(" ")
    attrs.merge(data: attrs[:data].merge(action:))
  end
end

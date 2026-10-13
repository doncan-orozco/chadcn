# frozen_string_literal: true

# shadcn Toggle over Radix Toggle. Spec: docs/shadcn-port/specs/toggle.md
class Phlex::Shadcn::Toggle < Phlex::Shadcn::Base
  BASE = "inline-flex items-center justify-center gap-2 rounded-md text-sm font-medium whitespace-nowrap transition-[color,box-shadow] outline-none hover:bg-muted hover:text-muted-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 data-[state=on]:bg-accent data-[state=on]:text-accent-foreground dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"

  VARIANTS = {
    "default" => "bg-transparent",
    "outline" => "border border-input bg-transparent shadow-xs hover:bg-accent hover:text-accent-foreground"
  }.freeze

  SIZES = {
    "default" => "h-9 min-w-9 px-2",
    "sm" => "h-8 min-w-8 px-1.5",
    "lg" => "h-10 min-w-10 px-2.5"
  }.freeze

  # React `toggleVariants`.
  def self.variants(variant: "default", size: "default", class: nil)
    new(variant:, size:).send(:classes, binding.local_variable_get(:class))
  end

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

  def view_template(&)
    attrs = merge_attrs(root_attrs, @attrs.except(:class))
    attrs = attrs.merge(class: [ @slot_class, classes(@attrs[:class]) ].compact_blank.join(" "))
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
      data: { state: @pressed ? "on" : "off", slot: "toggle", controller: "v2--toggle",
              v2__toggle_controlled_value: @controlled, v2__toggle_disabled_value: @disabled,
              **(@disabled ? { disabled: "" } : {}) },
      disabled: @disabled
    }
  end

  # Radix runs the consumer onClick first, then the toggle: our action goes last.
  def with_action(attrs)
    action = [ attrs.dig(:data, :action), "click->v2--toggle#toggle" ].compact_blank.join(" ")
    attrs.merge(data: attrs[:data].merge(action:))
  end
end

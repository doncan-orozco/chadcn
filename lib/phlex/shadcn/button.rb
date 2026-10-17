# frozen_string_literal: true

# shadcn `Button` (new-york-v4). Spec: docs/shadcn-port/specs/button.md
using Phlex::Shadcn::Values::Refinements

# A clickable button, the shadcn `Button` with its variant and size tables.
#
# Renders a `<button>` carrying `data-slot="button"`, `data-variant` and `data-size`. Extra kwargs become HTML
# attributes (`data:`/`aria:` are deep-merged, `class:` wins Tailwind conflicts).
#
# @example A secondary action
#   render Phlex::Shadcn::Button.new(variant: "outline") { "Save" }
# @example Rendering a link with button styles
#   render Phlex::Shadcn::Button.new(as_child: :a, href: "/docs") { "Docs" }
class Phlex::Shadcn::Button < Phlex::Shadcn::Base
  # Classes shared by every variant and size.
  #
  # @return [String]
  BASE = "inline-flex shrink-0 items-center justify-center gap-2 rounded-md text-sm font-medium whitespace-nowrap transition-all outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"

  # Variant name => Tailwind classes; the keys are the accepted values of `variant:`.
  #
  # @return [Hash{String => String}]
  VARIANTS = {
    "default" => "bg-primary text-primary-foreground hover:bg-primary/90",
    "destructive" => "bg-destructive text-white hover:bg-destructive/90 focus-visible:ring-destructive/20 dark:bg-destructive/60 dark:focus-visible:ring-destructive/40",
    "outline" => "border bg-background shadow-xs hover:bg-accent hover:text-accent-foreground dark:border-input dark:bg-input/30 dark:hover:bg-input/50",
    "secondary" => "bg-secondary text-secondary-foreground hover:bg-secondary/80",
    "ghost" => "hover:bg-accent hover:text-accent-foreground dark:hover:bg-accent/50",
    "link" => "text-primary underline-offset-4 hover:underline"
  }.freeze

  # Size name => Tailwind classes; the keys are the accepted values of `size:`.
  #
  # @return [Hash{String => String}]
  SIZES = {
    "default" => "h-9 px-4 py-2 has-[>svg]:px-3",
    "xs" => "h-6 gap-1 rounded-md px-2 text-xs has-[>svg]:px-1.5 [&_svg:not([class*='size-'])]:size-3",
    "sm" => "h-8 gap-1.5 rounded-md px-3 has-[>svg]:px-2.5",
    "lg" => "h-10 rounded-md px-6 has-[>svg]:px-4",
    "icon" => "size-9",
    "icon-xs" => "size-6 rounded-md [&_svg:not([class*='size-'])]:size-3",
    "icon-sm" => "size-8",
    "icon-lg" => "size-10"
  }.freeze

  # Class string of a button, to style non-button elements the same way (React `buttonVariants`).
  #
  # @param variant [String, Symbol, nil] one of VARIANTS (nil means "default"); underscores are normalized
  # @param size [String, Symbol, nil] one of SIZES (nil means "default"); underscores are normalized (`:icon_sm` is `"icon-sm"`)
  # @param class [String, nil] extra classes, merged last
  # @return [String]
  # @raise [ArgumentError] when the variant or size is unknown
  # @example
  #   a(href: "/x", class: Phlex::Shadcn::Button.variants(variant: "link")) { "Read more" }
  def self.variants(variant: "default", size: "default", class: nil)
    new(variant: variant, size: size).send(:classes, binding.local_variable_get(:class))
  end

  # @param variant [String, Symbol, nil] one of VARIANTS (nil means "default")
  # @param size [String, Symbol, nil] one of SIZES (nil means "default"); underscores are normalized (`:icon_sm` is `"icon-sm"`)
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base]
  #   the tag (`:a`) or component instance to render instead of a `<button>`, merging the button props
  #   into it; false renders the default `<button>`
  # @param attrs [Hash] HTML attributes (`type:`, `disabled:`, `class:`, `data:`, `aria:`...)
  # @raise [ArgumentError] when the variant or size is unknown
  def initialize(variant: "default", size: "default", as_child: false, **attrs)
    @variant = resolve(VARIANTS, variant, "variant")
    @size = resolve(SIZES, size, "size")
    @as_child = as_child
    @attrs = attrs
  end

  # @yield the button content
  # @return [void]
  def view_template(&)
    attrs = merge_attrs({ data: { slot: "button", variant: @variant, size: @size } }, @attrs.except(:class))
    attrs = attrs.merge(class: [ @slot_class, classes(@attrs[:class]) ].reject_blank.join(" "))
    return render_as_child(@as_child, **attrs, &) if @as_child

    button(**attrs, &)
  end

  private

  def classes(extra) = cn(BASE, VARIANTS[@variant], SIZES[@size], extra)

  def resolve(table, value, label)
    key = normalize_option(value) || "default"
    return key if table.key?(key)

    raise ArgumentError, "unknown #{label}: #{value.inspect} (expected one of #{table.keys.join(', ')})"
  end
end

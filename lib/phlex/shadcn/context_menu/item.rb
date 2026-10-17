# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# shadcn ContextMenuItem: a +div+ with +role="menuitem"+. Selecting it (click, Enter, Space) dispatches the cancelable,
# bubbling +shadcn--context-menu:select+ event on the item and then closes the menu unless that event was prevented.
#
# @example
#   menu.item(variant: :destructive) { "Delete" }
class Phlex::Shadcn::ContextMenu::Item < Phlex::Shadcn::Base
  include Phlex::Shadcn::ContextMenu::Support

  # @return [String] the default Tailwind classes (shadcn new-york-v4)
  CLASSES = "relative flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 data-[inset]:pl-8 data-[variant=destructive]:text-destructive data-[variant=destructive]:focus:bg-destructive/10 data-[variant=destructive]:focus:text-destructive dark:data-[variant=destructive]:focus:bg-destructive/20 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground data-[variant=destructive]:*:[svg]:text-destructive!"

  # @param variant [String, Symbol] rendered as +data-variant+; the stylesheet knows +"default"+ (default) and +"destructive"+.
  #   Not validated
  # @param inset [Boolean, nil] rendered as +data-inset+ (+"true"+/+"false"+) when not +nil+; +true+ adds left padding
  #   (default +nil+: no attribute)
  # @param disabled [Boolean] +true+ renders +data-disabled+ and +aria-disabled="true"+ (default +false+)
  # @param text_value [String, nil] rendered as +data-text-value+ (typeahead text); omitted when +nil+
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that element/component instead, with this part's attributes merged into it
  #   (Radix Slot)
  # @param attrs [Hash] HTML attributes for the element; +class+ is merged with the defaults through tailwind-merge, +data+ and
  #   +aria+ are deep-merged (the caller wins)
  def initialize(variant: "default", inset: nil, disabled: false, text_value: nil, as_child: false, **attrs)
    @variant = variant.to_s
    @inset = inset
    @disabled = disabled
    @text_value = text_value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the label of the item
  # @return [void]
  def view_template(&)
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).merge_deep(
      role: "menuitem", class: CLASSES,
      data: { slot: "context-menu-item", inset: inset_value(@inset), variant: @variant }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs), &)
  end
end

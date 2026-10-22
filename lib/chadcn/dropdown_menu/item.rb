# frozen_string_literal: true

using Chadcn::Values::Refinements

# Radix MenuItem: a +div role="menuitem"+. Activating it (click, Enter, Space) dispatches +select+ (cancelable: preventing
# it keeps the menu open) and closes the menu. Disabled items are skipped by keyboard navigation and ignore activation.
#
# @example
#   menu.item { "Profile" }
#   menu.item(variant: "destructive", inset: true) { "Delete" }
#   menu.item(disabled: true, text_value: "Archive") { "Archive (soon)" }
class Chadcn::DropdownMenu::Item < Chadcn::Base
  include Chadcn::DropdownMenu::Support

  # Default Tailwind classes of the item (merged with +class:+).
  #
  # @return [String]
  CLASSES = "relative flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 data-[inset]:pl-8 data-[variant=destructive]:text-destructive data-[variant=destructive]:focus:bg-destructive/10 data-[variant=destructive]:focus:text-destructive dark:data-[variant=destructive]:focus:bg-destructive/20 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground data-[variant=destructive]:*:[svg]:text-destructive!"

  # @param variant ["default", "destructive", Symbol, String] rendered as +data-variant+ (converted with +to_s+, not
  #   validated), default +"default"+
  # @param inset [Boolean, nil] +nil+ (default) omits +data-inset+; +true+/+false+ render +data-inset="true"+/+"false"+
  # @param disabled [Boolean] default +false+; renders +data-disabled+ and +aria-disabled+
  # @param text_value [String, nil] text used by typeahead instead of the item's text, default +nil+
  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that instead, receiving this part's attributes merged in (Radix Slot)
  # @param attrs [Hash] extra HTML attributes merged over the defaults: +class:+ is merged with tailwind_merge,
  #   +data:+ and +aria:+ hashes are deep merged
  def initialize(variant: "default", inset: nil, disabled: false, text_value: nil, as_child: false, **attrs)
    @variant = variant.to_s
    @inset = inset
    @disabled = disabled
    @text_value = text_value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the item content
  # @return [void]
  def view_template(&)
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).merge_deep(
      role: "menuitem", class: CLASSES,
      data: { slot: "dropdown-menu-item", inset: inset_value(@inset), variant: @variant }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs), &)
  end
end

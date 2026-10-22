# frozen_string_literal: true

using Chadcn::Values::Refinements

# A menu item (+role="menuitem"+). Choosing it dispatches a cancelable +select+ event (+chadcn--menubar:select+) on the item
# and closes the menu unless the event is prevented.
#
# @example
#   bar.item(variant: "destructive") { "Delete" }
class Chadcn::Menubar::Item < Chadcn::Base
  include Chadcn::Menubar::Support

  # @return [String] default Tailwind classes; the +class:+ you pass is merged on top
  CLASSES = "relative flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 data-[inset]:pl-8 data-[variant=destructive]:text-destructive data-[variant=destructive]:focus:bg-destructive/10 data-[variant=destructive]:focus:text-destructive dark:data-[variant=destructive]:focus:bg-destructive/20 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground data-[variant=destructive]:*:[svg]:text-destructive!"

  # @param variant [String, Symbol] +"default"+ or +"destructive"+ (rendered as +data-variant+, not validated). Default +"default"+
  # @param inset [Boolean, nil] adds left padding to align with items that have an indicator (+data-inset+). +nil+ renders nothing, +false+ renders
  #   +data-inset="false"+ (which still matches +data-[inset]:pl-8+, so it pads like +true+). Default +nil+
  # @param disabled [Boolean] renders +aria-disabled+ and +data-disabled+ so the item cannot be chosen. Default +false+
  # @param text_value [String, nil] text the typeahead matches against (+data-text-value+); defaults to the item's text. Default +nil+
  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String or a component instance
  #   renders that element carrying this part's attributes instead
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with {CLASSES} (yours wins Tailwind conflicts), +data+/+aria+ are deep merged
  def initialize(variant: "default", inset: nil, disabled: false, text_value: nil, as_child: false, **attrs)
    @variant = variant.to_s
    @inset = inset
    @disabled = disabled
    @text_value = text_value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  def view_template(&)
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).merge_deep(
      role: "menuitem", class: CLASSES,
      data: { slot: "menubar-item", inset: inset_value(@inset), variant: @variant }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs), &)
  end
end

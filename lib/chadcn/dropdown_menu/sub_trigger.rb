# frozen_string_literal: true

using Chadcn::Values::Refinements

# Radix MenuSubTrigger: a +div role="menuitem"+ that opens its Sub (click, Enter, Space or the arrow key towards the
# sub menu, pointer hover) and shows a trailing chevron after the content.
#
# @example
#   menu.sub_trigger(inset: true) { "More" }
class Chadcn::DropdownMenu::SubTrigger < Chadcn::Base
  include Chadcn::DropdownMenu::Support

  # Default Tailwind classes of the sub trigger (merged with +class:+).
  #
  # @return [String]
  CLASSES = "flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[inset]:pl-8 data-[state=open]:bg-accent data-[state=open]:text-accent-foreground [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground"

  # @param inset [Boolean, nil] +nil+ (default) omits +data-inset+; +true+/+false+ render +data-inset="true"+/+"false"+
  # @param disabled [Boolean] default +false+; renders +data-disabled+ and +aria-disabled+
  # @param text_value [String, nil] text used by typeahead, default +nil+
  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that instead, receiving this part's attributes merged in (Radix Slot)
  # @param attrs [Hash] extra HTML attributes merged over the defaults: +class:+ is merged with tailwind_merge,
  #   +data:+ and +aria:+ hashes are deep merged
  def initialize(inset: nil, disabled: false, text_value: nil, as_child: false, **attrs)
    @inset = inset
    @disabled = disabled
    @text_value = text_value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the trigger content (the chevron icon is rendered after it)
  # @raise [ArgumentError] when rendered outside a DropdownMenu::Sub
  # @return [void]
  def view_template
    sub = context[Chadcn::DropdownMenu::SUB_KEY] or raise ArgumentError, "#{self.class.name} must be used within DropdownMenu::Sub"
    open = sub[:open]
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).merge_deep(
      role: "menuitem", id: sub[:trigger_id], class: CLASSES,
      aria: { haspopup: "menu", expanded: open.to_s, controls: (sub[:content_id] if open) },
      data: {
        slot: "dropdown-menu-sub-trigger", state: open ? "open" : "closed", inset: inset_value(@inset),
        shadcn__dropdown_menu_sub_content_id: sub[:content_id], shadcn__dropdown_menu_sub_controlled: sub[:controlled].to_s
      }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs)) do
      yield if block_given?
      render Chadcn::Icon.new("chevron-right", class: "ml-auto size-4")
    end
  end
end

# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn ContextMenuSubTrigger: a +div+ with +role="menuitem"+ and +aria-haspopup="menu"+ that opens its {SubContent}, followed by
# a chevron icon. +data-state+ and +aria-expanded+ follow the enclosing {Sub}.
#
# @example
#   menu.sub_trigger(inset: true) { "More tools" }
class Chadcn::ContextMenu::SubTrigger < Chadcn::Base
  include Chadcn::ContextMenu::Support

  # @return [String] the default Tailwind classes (shadcn new-york-v4)
  CLASSES = "flex cursor-default items-center rounded-sm px-2 py-1.5 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[inset]:pl-8 data-[state=open]:bg-accent data-[state=open]:text-accent-foreground [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground"

  # @param inset [Boolean, nil] rendered as +data-inset+ (+"true"+/+"false"+) when not +nil+; +true+ adds left padding
  #   (default +nil+: no attribute)
  # @param disabled [Boolean] +true+ renders +data-disabled+ and +aria-disabled="true"+ (default +false+)
  # @param text_value [String, nil] rendered as +data-text-value+ (typeahead text); omitted when +nil+
  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that element/component instead, with this part's attributes merged into it
  #   (Radix Slot)
  # @param attrs [Hash] HTML attributes for the element; +class+ is merged with the defaults through tailwind-merge, +data+ and
  #   +aria+ are deep-merged (the caller wins)
  def initialize(inset: nil, disabled: false, text_value: nil, as_child: false, **attrs)
    @inset = inset
    @disabled = disabled
    @text_value = text_value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the label of the trigger (the chevron is appended after it)
  # @return [void]
  # @raise [ArgumentError] when there is no surrounding {Sub}
  def view_template
    sub = context[Chadcn::ContextMenu::SUB_KEY] or raise ArgumentError, "#{self.class.name} must be used within ContextMenu::Sub"
    open = sub[:open]
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).merge_deep(
      role: "menuitem", id: sub[:trigger_id], class: CLASSES,
      aria: { haspopup: "menu", expanded: open.to_s, controls: (sub[:content_id] if open) },
      data: {
        slot: "context-menu-sub-trigger", state: open ? "open" : "closed", inset: inset_value(@inset),
        chadcn__dropdown_menu_sub_content_id: sub[:content_id], chadcn__dropdown_menu_sub_controlled: sub[:controlled].to_s
      }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs)) do
      yield if block_given?
      render Chadcn::Icon.new("chevron-right", class: "ml-auto")
    end
  end
end

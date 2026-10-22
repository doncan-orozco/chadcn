# frozen_string_literal: true

using Chadcn::Values::Refinements

# The item that opens a {Sub} (+role="menuitem"+, +aria-haspopup="menu"+), with a trailing chevron icon. Must be rendered
# inside a {Sub} (raises +ArgumentError+ at render otherwise).
#
# @example
#   bar.sub_trigger(inset: true) { "Share" }
class Chadcn::Menubar::SubTrigger < Chadcn::Base
  include Chadcn::Menubar::Support

  # @return [String] default Tailwind classes; the +class:+ you pass is merged on top
  CLASSES = "flex cursor-default items-center rounded-sm px-2 py-1.5 text-sm outline-none select-none focus:bg-accent focus:text-accent-foreground data-[inset]:pl-8 data-[state=open]:bg-accent data-[state=open]:text-accent-foreground"

  # @param inset [Boolean, nil] adds left padding to align with items that have an indicator (+data-inset+). +nil+ renders nothing, +false+ renders
  #   +data-inset="false"+. Default +nil+
  # @param disabled [Boolean] renders +aria-disabled+ and +data-disabled+ so the item cannot be chosen. Default +false+
  # @param text_value [String, nil] text the typeahead matches against (+data-text-value+); defaults to the item's text. Default +nil+
  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String or a component instance
  #   renders that element carrying this part's attributes instead
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with {CLASSES} (yours wins Tailwind conflicts), +data+/+aria+ are deep merged
  # @raise [ArgumentError] at render, when not inside a {Sub}
  def initialize(inset: nil, disabled: false, text_value: nil, as_child: false, **attrs)
    @inset = inset
    @disabled = disabled
    @text_value = text_value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the trigger's label (the chevron is appended after it)
  # @return [void]
  def view_template
    sub = context[Chadcn::Menubar::SUB_KEY] or raise ArgumentError, "#{self.class.name} must be used within Menubar::Sub"
    open = sub[:open]
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).merge_deep(
      role: "menuitem", id: sub[:trigger_id], class: CLASSES,
      aria: { haspopup: "menu", expanded: open.to_s, controls: (sub[:content_id] if open) },
      data: {
        slot: "menubar-sub-trigger", radix_menubar_subtrigger: "", state: open ? "open" : "closed", inset: inset_value(@inset),
        chadcn__menubar_sub_content_id: sub[:content_id], chadcn__menubar_sub_controlled: sub[:controlled].to_s
      }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs)) do
      yield if block_given?
      render Chadcn::Icon.new("chevron-right", class: "ml-auto h-4 w-4")
    end
  end
end

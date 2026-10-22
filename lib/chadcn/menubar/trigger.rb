# frozen_string_literal: true

# Radix MenubarTrigger: a +button+ that is a roving item of the root group and the anchor of its {Menu}. Must be rendered
# inside a {Menu} (raises +ArgumentError+ at render otherwise).
#
# @example
#   bar.trigger { "File" }
class Chadcn::Menubar::Trigger < Chadcn::Base
  include Chadcn::Menubar::Support

  # @return [String] default Tailwind classes; the +class:+ you pass is merged on top
  CLASSES = "flex items-center rounded-sm px-2 py-1 text-sm font-medium outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[state=open]:bg-accent data-[state=open]:text-accent-foreground"

  # @param disabled [Boolean] renders the +disabled+ attribute and +data-disabled+. Default +false+
  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String or a component instance
  #   renders that element carrying this part's attributes instead
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with {CLASSES} (yours wins Tailwind conflicts), +data+/+aria+ are deep merged
  # @raise [ArgumentError] at render, when not inside a {Menu}
  def initialize(disabled: false, as_child: false, **attrs)
    @disabled = disabled
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  def view_template(&)
    menu = menu_context
    open = menu[:open]
    attrs = merge_attrs({
                          type: "button", role: "menuitem", id: menu[:trigger_id], disabled: @disabled, tabindex: "-1", class: CLASSES,
                          aria: { haspopup: "menu", expanded: open.to_s, controls: (menu[:content_id] if open) },
                          data: {
                            slot: "menubar-trigger", state: open ? "open" : "closed", disabled: (@disabled ? "" : nil),
                            orientation: "horizontal", radix_collection_item: "",
                            chadcn__menubar_menu_value: menu[:value], chadcn__menubar_content_id: menu[:content_id]
                          }
                        }, @attrs)
    render_part(:button, @as_child, attrs, &)
  end
end

# frozen_string_literal: true

# Radix MenubarTrigger: a roving item of the root group and the anchor of its menu.
class Phlex::Shadcn::Menubar::Trigger < Phlex::Shadcn::Base
  include Phlex::Shadcn::Menubar::Support

  CLASSES = "flex items-center rounded-sm px-2 py-1 text-sm font-medium outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[state=open]:bg-accent data-[state=open]:text-accent-foreground"

  def initialize(disabled: false, as_child: false, **attrs)
    @disabled = disabled
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    menu = menu_context
    open = menu[:open]
    attrs = merge_attrs({
                          type: "button", role: "menuitem", id: menu[:trigger_id], disabled: @disabled, tabindex: "-1", class: CLASSES,
                          aria: { haspopup: "menu", expanded: open.to_s, controls: (menu[:content_id] if open) },
                          data: {
                            slot: "menubar-trigger", state: open ? "open" : "closed", disabled: (@disabled ? "" : nil),
                            orientation: "horizontal", radix_collection_item: "",
                            shadcn__menubar_menu_value: menu[:value], shadcn__menubar_content_id: menu[:content_id]
                          }
                        }, @attrs)
    render_part(:button, @as_child, attrs, &)
  end
end

# frozen_string_literal: true

# Radix DropdownMenuTrigger. Hosts the shadcn--dropdown-menu controller for the root menu and all its subs.
class Phlex::Shadcn::DropdownMenu::Trigger < Phlex::Shadcn::Base
  include Phlex::Shadcn::DropdownMenu::Support

  def initialize(as_child: false, disabled: false, **attrs)
    @as_child = as_child
    @disabled = disabled
    @attrs = attrs
    super()
  end

  def view_template(&)
    root = root_context
    open = root[:open]
    attrs = merge_attrs({
                          type: "button", id: root[:trigger_id], disabled: @disabled,
                          aria: { haspopup: "menu", expanded: open.to_s, controls: (root[:content_id] if open) },
                          data: {
                            slot: "dropdown-menu-trigger", state: open ? "open" : "closed", disabled: (@disabled ? "" : nil),
                            controller: "shadcn--dropdown-menu", **values(root)
                          }
                        }, @attrs)
    render_part(:button, @as_child, attrs, &)
  end

  private

  def values(root)
    {
      shadcn__dropdown_menu_open_value: root[:open].to_s,
      shadcn__dropdown_menu_controlled_value: root[:controlled].to_s,
      shadcn__dropdown_menu_modal_value: root[:modal].to_s,
      shadcn__dropdown_menu_dir_value: root[:dir],
      shadcn__dropdown_menu_template_value: root[:content_id]
    }
  end
end

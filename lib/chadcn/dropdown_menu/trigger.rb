# frozen_string_literal: true

# Radix DropdownMenuTrigger: a +button+ that hosts the +shadcn--dropdown-menu+ controller for the root menu and all its
# subs. It carries the open/controlled/modal/dir values for the controller and +aria-haspopup+, +aria-expanded+ and
# +aria-controls+ (only while open). A primary-button pointerdown (no ctrl), Enter or Space
# toggles the menu; ArrowDown only opens it. All of them are ignored when +disabled+.
#
# @example
#   menu.trigger(class: "w-full") { "Open" }
#   menu.trigger(as_child: :span, class: "cursor-pointer") { "Open" }
class Chadcn::DropdownMenu::Trigger < Chadcn::Base
  include Chadcn::DropdownMenu::Support

  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that instead, receiving this part's attributes merged in (Radix Slot)
  # @param disabled [Boolean] default +false+; renders +disabled+ and +data-disabled+
  # @param attrs [Hash] extra HTML attributes merged over the defaults: +class:+ is merged with tailwind_merge,
  #   +data:+ and +aria:+ hashes are deep merged
  def initialize(as_child: false, disabled: false, **attrs)
    @as_child = as_child
    @disabled = disabled
    @attrs = attrs
    super()
  end

  # @yield the trigger content
  # @raise [ArgumentError] when rendered outside a DropdownMenu
  # @return [void]
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

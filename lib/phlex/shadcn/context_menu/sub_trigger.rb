# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::ContextMenu::SubTrigger < Phlex::Shadcn::Base
  include Phlex::Shadcn::ContextMenu::Support

  CLASSES = "flex cursor-default items-center rounded-sm px-2 py-1.5 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[inset]:pl-8 data-[state=open]:bg-accent data-[state=open]:text-accent-foreground [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground"

  def initialize(inset: nil, disabled: false, text_value: nil, as_child: false, **attrs)
    @inset = inset
    @disabled = disabled
    @text_value = text_value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template
    sub = context[Phlex::Shadcn::ContextMenu::SUB_KEY] or raise ArgumentError, "#{self.class.name} must be used within ContextMenu::Sub"
    open = sub[:open]
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).merge_deep(
      role: "menuitem", id: sub[:trigger_id], class: CLASSES,
      aria: { haspopup: "menu", expanded: open.to_s, controls: (sub[:content_id] if open) },
      data: {
        slot: "context-menu-sub-trigger", state: open ? "open" : "closed", inset: inset_value(@inset),
        shadcn__dropdown_menu_sub_content_id: sub[:content_id], shadcn__dropdown_menu_sub_controlled: sub[:controlled].to_s
      }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs)) do
      yield if block_given?
      render Phlex::Shadcn::Icon.new("chevron-right", class: "ml-auto")
    end
  end
end

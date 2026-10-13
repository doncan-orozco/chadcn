# frozen_string_literal: true

class Phlex::Shadcn::Menubar::SubTrigger < Phlex::Shadcn::Base
  include Phlex::Shadcn::Menubar::Support

  CLASSES = "flex cursor-default items-center rounded-sm px-2 py-1.5 text-sm outline-none select-none focus:bg-accent focus:text-accent-foreground data-[inset]:pl-8 data-[state=open]:bg-accent data-[state=open]:text-accent-foreground"

  def initialize(inset: nil, disabled: false, text_value: nil, as_child: false, **attrs)
    @inset = inset
    @disabled = disabled
    @text_value = text_value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template
    sub = context[Phlex::Shadcn::Menubar::SUB_KEY] or raise ArgumentError, "#{self.class.name} must be used within Menubar::Sub"
    open = sub[:open]
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).deep_merge(
      role: "menuitem", id: sub[:trigger_id], class: CLASSES,
      aria: { haspopup: "menu", expanded: open.to_s, controls: (sub[:content_id] if open) },
      data: {
        slot: "menubar-sub-trigger", radix_menubar_subtrigger: "", state: open ? "open" : "closed", inset: inset_value(@inset),
        v2__menubar_sub_content_id: sub[:content_id], v2__menubar_sub_controlled: sub[:controlled].to_s
      }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs)) do
      yield if block_given?
      render Phlex::Shadcn::Icon.new("chevron-right", class: "ml-auto h-4 w-4")
    end
  end
end

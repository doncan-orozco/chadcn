# frozen_string_literal: true

class Phlex::Shadcn::DropdownMenu::Item < Phlex::Shadcn::Base
  include Phlex::Shadcn::DropdownMenu::Support

  CLASSES = "relative flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground data-[disabled]:pointer-events-none data-[disabled]:opacity-50 data-[inset]:pl-8 data-[variant=destructive]:text-destructive data-[variant=destructive]:focus:bg-destructive/10 data-[variant=destructive]:focus:text-destructive dark:data-[variant=destructive]:focus:bg-destructive/20 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground data-[variant=destructive]:*:[svg]:text-destructive!"

  def initialize(variant: "default", inset: nil, disabled: false, text_value: nil, as_child: false, **attrs)
    @variant = variant.to_s
    @inset = inset
    @disabled = disabled
    @text_value = text_value
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    defaults = item_attrs(disabled: @disabled, text_value: @text_value).deep_merge(
      role: "menuitem", class: CLASSES,
      data: { slot: "dropdown-menu-item", inset: inset_value(@inset), variant: @variant }
    )
    render_part(:div, @as_child, merge_attrs(defaults, @attrs), &)
  end
end

# frozen_string_literal: true

# A plain span in the oracle (no Radix primitive, so no as_child).
class Phlex::Shadcn::DropdownMenu::Shortcut < Phlex::Shadcn::Base
  CLASSES = "ml-auto text-xs tracking-widest text-muted-foreground"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    span(**merge_attrs({ class: CLASSES, data: { slot: "dropdown-menu-shortcut" } }, @attrs), &)
  end
end

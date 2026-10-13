# frozen_string_literal: true

# A plain span in the oracle (no Radix primitive, so no as_child).
class Phlex::Shadcn::Menubar::Shortcut < Phlex::Shadcn::Base
  CLASSES = "ml-auto text-xs tracking-widest text-muted-foreground"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    span(**merge_attrs({ class: CLASSES, data: { slot: "menubar-shortcut" } }, @attrs), &)
  end
end

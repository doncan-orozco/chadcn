# frozen_string_literal: true

# shadcn SheetFooter.
class Phlex::Shadcn::Sheet::Footer < Phlex::Shadcn::Base
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    div(**merge_attrs({ class: "mt-auto flex flex-col gap-2 p-4", data: { slot: "sheet-footer" } }, @attrs), &)
  end
end

# frozen_string_literal: true

# shadcn SheetFooter.
#
# Layout wrapper for the actions (`div`).
class Chadcn::Sheet::Footer < Chadcn::Base
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  def view_template(&)
    div(**merge_attrs({ class: "mt-auto flex flex-col gap-2 p-4", data: { slot: "sheet-footer" } }, @attrs), &)
  end
end

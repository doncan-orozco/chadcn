# frozen_string_literal: true

# shadcn DrawerFooter.
#
# Layout wrapper for the actions (`div`).
class Chadcn::Drawer::Footer < Chadcn::Base
  # @api private
  CLASSES = "mt-auto flex flex-col gap-2 p-4"

  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  def view_template(&)
    div(**merge_attrs({ class: CLASSES, data: { slot: "drawer-footer" } }, @attrs), &)
  end
end

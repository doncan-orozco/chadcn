# frozen_string_literal: true

# shadcn DrawerHeader.
#
# Layout wrapper for the title and description (`div`).
class Chadcn::Drawer::Header < Chadcn::Base
  # @api private
  CLASSES = "flex flex-col gap-0.5 p-4 group-data-[vaul-drawer-direction=bottom]/drawer-content:text-center group-data-[vaul-drawer-direction=top]/drawer-content:text-center md:gap-1.5 md:text-left"

  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  def view_template(&)
    div(**merge_attrs({ class: CLASSES, data: { slot: "drawer-header" } }, @attrs), &)
  end
end

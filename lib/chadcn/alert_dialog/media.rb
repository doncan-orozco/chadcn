# frozen_string_literal: true

# shadcn AlertDialogMedia.
#
# Icon/image slot above the title (`div`).
class Chadcn::AlertDialog::Media < Chadcn::Base
  # @api private
  CLASSES = "mb-2 inline-flex size-16 items-center justify-center rounded-md bg-muted sm:group-data-[size=default]/alert-dialog-content:row-span-2 *:[svg:not([class*='size-'])]:size-8"

  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  def view_template(&)
    div(**merge_attrs({ class: CLASSES, data: { slot: "alert-dialog-media" } }, @attrs), &)
  end
end

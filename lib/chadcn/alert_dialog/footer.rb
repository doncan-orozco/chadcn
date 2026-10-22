# frozen_string_literal: true

# shadcn AlertDialogFooter.
#
# Layout wrapper for the actions (`div`).
class Chadcn::AlertDialog::Footer < Chadcn::Base
  # @api private
  CLASSES = "flex flex-col-reverse gap-2 group-data-[size=sm]/alert-dialog-content:grid group-data-[size=sm]/alert-dialog-content:grid-cols-2 sm:flex-row sm:justify-end"

  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  def view_template(&)
    div(**merge_attrs({ class: CLASSES, data: { slot: "alert-dialog-footer" } }, @attrs), &)
  end
end

# frozen_string_literal: true

# shadcn AlertDialogFooter.
class Phlex::Shadcn::AlertDialog::Footer < Phlex::Shadcn::Base
  CLASSES = "flex flex-col-reverse gap-2 group-data-[size=sm]/alert-dialog-content:grid group-data-[size=sm]/alert-dialog-content:grid-cols-2 sm:flex-row sm:justify-end"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    div(**merge_attrs({ class: CLASSES, data: { slot: "alert-dialog-footer" } }, @attrs), &)
  end
end

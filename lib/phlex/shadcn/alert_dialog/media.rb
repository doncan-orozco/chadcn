# frozen_string_literal: true

# shadcn AlertDialogMedia.
class Phlex::Shadcn::AlertDialog::Media < Phlex::Shadcn::Base
  CLASSES = "mb-2 inline-flex size-16 items-center justify-center rounded-md bg-muted sm:group-data-[size=default]/alert-dialog-content:row-span-2 *:[svg:not([class*='size-'])]:size-8"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    div(**merge_attrs({ class: CLASSES, data: { slot: "alert-dialog-media" } }, @attrs), &)
  end
end

# frozen_string_literal: true

# shadcn AlertDialogHeader.
class Phlex::Shadcn::AlertDialog::Header < Phlex::Shadcn::Base
  CLASSES = "grid grid-rows-[auto_1fr] place-items-center gap-1.5 text-center has-data-[slot=alert-dialog-media]:grid-rows-[auto_auto_1fr] has-data-[slot=alert-dialog-media]:gap-x-6 sm:group-data-[size=default]/alert-dialog-content:place-items-start sm:group-data-[size=default]/alert-dialog-content:text-left sm:group-data-[size=default]/alert-dialog-content:has-data-[slot=alert-dialog-media]:grid-rows-[auto_1fr]"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    div(**merge_attrs({ class: CLASSES, data: { slot: "alert-dialog-header" } }, @attrs), &)
  end
end

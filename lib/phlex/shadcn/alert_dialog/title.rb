# frozen_string_literal: true

# shadcn AlertDialogTitle. Marks the dialog as titled so Content can emit aria-labelledby.
class Phlex::Shadcn::AlertDialog::Title < Phlex::Shadcn::Base
  include Phlex::Shadcn::AlertDialog::Support

  CLASSES = "text-lg font-semibold sm:group-data-[size=default]/alert-dialog-content:group-has-data-[slot=alert-dialog-media]/alert-dialog-content:col-start-2"

  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    root = root_context
    root[:title_present] = true
    attrs = merge_attrs({ id: root[:title_id], class: CLASSES, data: { slot: "alert-dialog-title" } }, @attrs)
    render_part(:h2, @as_child, attrs, &)
  end
end

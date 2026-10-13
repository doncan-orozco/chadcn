# frozen_string_literal: true

# shadcn AlertDialogDescription. Marks the dialog as described so Content can emit aria-describedby.
class Phlex::Shadcn::AlertDialog::Description < Phlex::Shadcn::Base
  include Phlex::Shadcn::AlertDialog::Support

  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    root = root_context
    root[:description_present] = true
    attrs = merge_attrs({ id: root[:description_id], class: "text-sm text-muted-foreground", data: { slot: "alert-dialog-description" } },
                        @attrs)
    render_part(:p, @as_child, attrs, &)
  end
end

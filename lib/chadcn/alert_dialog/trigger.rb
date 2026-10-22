# frozen_string_literal: true

# Radix AlertDialogTrigger: toggles the dialog. aria-controls only exists while open (dialog:80-87).
#
# Toggles the alert dialog (renders a `button`; `aria-controls` only while open).
#
# @example Explicit form
#   render Chadcn::AlertDialog::Trigger.new { "Open" }
# @example Yielded-root helper form
#   alert_dialog.trigger { "Open" }
class Chadcn::AlertDialog::Trigger < Chadcn::Base
  include Chadcn::AlertDialog::Support

  # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the button content
  # @return [void]
  # @raise [ArgumentError] when rendered outside AlertDialog
  def view_template(&)
    root = root_context
    attrs = merge_attrs({
                          type: "button",
                          aria: { haspopup: "dialog", expanded: root[:open].to_s, controls: (root[:content_id] if root[:open]) },
                          data: { slot: "alert-dialog-trigger", state: state_of(root), shadcn__dialog_part: "trigger",
                                  action: "click->shadcn--alert-dialog#toggle" }
                        }, @attrs)
    render_part(:button, @as_child, attrs, &)
  end
end

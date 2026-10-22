# frozen_string_literal: true

# Radix DialogTrigger: toggles the dialog. aria-controls only exists while open (dialog:80-87).
#
# Toggles the dialog (renders a `button`; `aria-controls` only while open).
#
# @example Explicit form
#   render Chadcn::Dialog::Trigger.new { "Open" }
# @example Yielded-root helper form
#   dialog.trigger { "Open" }
class Chadcn::Dialog::Trigger < Chadcn::Base
  include Chadcn::Dialog::Support

  # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the button content
  # @return [void]
  # @raise [ArgumentError] when rendered outside Dialog
  def view_template(&)
    root = root_context
    attrs = merge_attrs({
                          type: "button",
                          aria: { haspopup: "dialog", expanded: root[:open].to_s, controls: (root[:content_id] if root[:open]) },
                          data: { slot: "dialog-trigger", state: state_of(root), chadcn__dialog_part: "trigger",
                                  action: "click->chadcn--dialog#toggle" }
                        }, @attrs)
    render_part(:button, @as_child, attrs, &)
  end
end

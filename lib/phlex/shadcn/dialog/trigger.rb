# frozen_string_literal: true

# Radix DialogTrigger: toggles the dialog. aria-controls only exists while open (dialog:80-87).
class Phlex::Shadcn::Dialog::Trigger < Phlex::Shadcn::Base
  include Phlex::Shadcn::Dialog::Support

  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    root = root_context
    attrs = merge_attrs({
                          type: "button",
                          aria: { haspopup: "dialog", expanded: root[:open].to_s, controls: (root[:content_id] if root[:open]) },
                          data: { slot: "dialog-trigger", state: state_of(root), shadcn__dialog_part: "trigger",
                                  action: "click->shadcn--dialog#toggle" }
                        }, @attrs)
    render_part(:button, @as_child, attrs, &)
  end
end

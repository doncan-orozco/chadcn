# frozen_string_literal: true

# Radix DialogTrigger: toggles the sheet. aria-controls only exists while open (dialog:80-87).
class Phlex::Shadcn::Sheet::Trigger < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sheet::Support

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
                          data: { slot: "sheet-trigger", state: state_of(root), shadcn__dialog_part: "trigger",
                                  action: "click->shadcn--sheet#toggle" }
                        }, @attrs)
    render_part(:button, @as_child, attrs, &)
  end
end

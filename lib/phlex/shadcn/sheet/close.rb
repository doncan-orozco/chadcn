# frozen_string_literal: true

# Radix DialogClose: no data-state and no aria attributes (dialog:305-312).
class Phlex::Shadcn::Sheet::Close < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sheet::Support

  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # data-v2--dialog-part is the marker the shared dialog controller looks for.
  def view_template(&)
    attrs = merge_attrs({
                          type: "button", data: { slot: "sheet-close", v2__dialog_part: "close", action: "click->v2--sheet#close" }
                        }, @attrs)
    render_part(:button, @as_child, attrs, &)
  end
end

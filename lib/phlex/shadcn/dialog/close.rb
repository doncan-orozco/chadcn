# frozen_string_literal: true

# Radix DialogClose: no data-state and no aria attributes (dialog:305-312).
class Phlex::Shadcn::Dialog::Close < Phlex::Shadcn::Base
  include Phlex::Shadcn::Dialog::Support

  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    attrs = merge_attrs({
                          type: "button", data: { slot: "dialog-close", shadcn__dialog_part: "close", action: "click->shadcn--dialog#close" }
                        }, @attrs)
    render_part(:button, @as_child, attrs, &)
  end
end

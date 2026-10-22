# frozen_string_literal: true

# Radix DialogClose: no data-state and no aria attributes (dialog:305-312).
#
# Closes the dialog (renders a `button`).
class Chadcn::Dialog::Close < Chadcn::Base
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
  def view_template(&)
    attrs = merge_attrs({
                          type: "button", data: { slot: "dialog-close", shadcn__dialog_part: "close", action: "click->shadcn--dialog#close" }
                        }, @attrs)
    render_part(:button, @as_child, attrs, &)
  end
end

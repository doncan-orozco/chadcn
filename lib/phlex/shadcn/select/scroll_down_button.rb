# frozen_string_literal: true

# Radix SelectScrollDownButton: Content renders one automatically, explicit ones go inside the viewport. The controller keeps
# the node out of the document until the viewport can scroll down (sel:L976-1065).
class Phlex::Shadcn::Select::ScrollDownButton < Phlex::Shadcn::Base
  include Phlex::Shadcn::Select::Support

  CLASSES = "flex cursor-default items-center justify-center py-1"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template
    attrs = merge_attrs(
      { aria: { hidden: "true" }, class: CLASSES, style: "flex-shrink: 0;", data: { slot: "select-scroll-down-button" } }, @attrs
    )
    div(**attrs) { render Phlex::Shadcn::Icon.new("chevron-down", class: "size-4") }
  end
end

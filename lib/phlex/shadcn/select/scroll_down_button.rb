# frozen_string_literal: true

# Chevron-down button shown by the controller when the viewport can scroll down; until then the controller keeps the node out of the
# document. {Phlex::Shadcn::Select::Content} already renders one above and one below the viewport, and the controller tracks every
# scroll button it finds, so an explicit one is an extra duplicate.
#
# @example
#   select.scroll_down_button
class Phlex::Shadcn::Select::ScrollDownButton < Phlex::Shadcn::Base
  include Phlex::Shadcn::Select::Support

  # @return [String] Tailwind classes of the button
  CLASSES = "flex cursor-default items-center justify-center py-1"

  # @param attrs [Hash] HTML attributes merged into the element (+class+ is merged with Tailwind conflict resolution, +data+/+aria+ deep-merged, caller wins)
  # @return [void]
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @return [void]
  def view_template
    attrs = merge_attrs(
      { aria: { hidden: "true" }, class: CLASSES, style: "flex-shrink: 0;", data: { slot: "select-scroll-down-button" } }, @attrs
    )
    div(**attrs) { render Phlex::Shadcn::Icon.new("chevron-down", class: "size-4") }
  end
end

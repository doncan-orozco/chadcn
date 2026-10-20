# frozen_string_literal: true

# shadcn CommandList: the listbox (`div`) around cmdk's inner sizer `div`.
#
# @example
#   render Phlex::Shadcn::Command::List.new { "..." }
class Phlex::Shadcn::Command::List < Phlex::Shadcn::Base
  include Phlex::Shadcn::Command::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "max-h-[300px] scroll-py-1 overflow-x-hidden overflow-y-auto"

  # @param label [String] the list's `aria-label`
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(label: "Suggestions", **attrs)
    @label = label
    @attrs = attrs
    super()
  end

  # @yield the items, groups, separators and empty state
  # @return [void]
  # @raise [ArgumentError] when rendered outside Command
  def view_template
    root = root_context
    attrs = merge_attrs({ class: CLASSES, data: { slot: "command-list" } }, @attrs)
    attrs = with_forced(attrs, { "cmdk-list": "", role: "listbox", tabindex: "-1", id: "#{root[:base]}-list" }, aria: { label: @label })
    div(**attrs) { div("cmdk-list-sizer": "") { yield if block_given? } }
  end
end

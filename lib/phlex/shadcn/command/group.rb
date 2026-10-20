# frozen_string_literal: true

# shadcn CommandGroup: a titled set of items (`div` > heading + `cmdk-group-items`). Hidden while none of its items match.
#
# @example
#   render(Phlex::Shadcn::Command::Group.new(heading: "Suggestions") { "..." })
class Phlex::Shadcn::Command::Group < Phlex::Shadcn::Base
  include Phlex::Shadcn::Command::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "overflow-hidden p-1 text-foreground [&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-xs [&_[cmdk-group-heading]]:font-medium [&_[cmdk-group-heading]]:text-muted-foreground"

  # @param heading [String, nil] the group's title
  # @param value [String, nil] the group's value (defaults to the heading)
  # @param force_mount [Boolean] keep the group (and its items) visible whatever the search
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(heading: nil, value: nil, force_mount: false, **attrs)
    @heading = heading
    @value = value
    @force_mount = force_mount
    @attrs = attrs
    super()
  end

  # @yield the group's items
  # @return [void]
  # @raise [ArgumentError] when rendered outside Command
  def view_template
    root = root_context
    id = next_id(root, :groups)
    div(**group_attrs) do
      div("cmdk-group-heading": "", aria: { hidden: "true" }, id: "#{id}-heading") { plain @heading } if @heading
      div("cmdk-group-items": "", role: "group", aria: { labelledby: (@heading ? "#{id}-heading" : nil) }) { yield if block_given? }
    end
  end

  private

  def group_value = (@value || @heading || "undefined").to_s.strip

  def group_attrs
    attrs = merge_attrs({ class: CLASSES, data: { slot: "command-group" } }, @attrs)
    # React keeps `value` in the rest props it spreads on the div (cmdk:204), then writes the trimmed data-value.
    attrs = with_forced(attrs, { "cmdk-group": "", role: "presentation", value: @value }.compact, data: { value: group_value })
    @force_mount ? with_forced(attrs, {}, data: { shadcn__command_force_mount: "true" }) : attrs
  end
end

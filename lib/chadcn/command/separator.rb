# frozen_string_literal: true

# shadcn CommandSeparator: a rule between groups (`div`, `role="separator"`). Present only while the search is empty,
# unless `always_render`.
#
# @example
#   render Chadcn::Command::Separator.new
class Chadcn::Command::Separator < Chadcn::Base
  include Chadcn::Command::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "-mx-1 h-px bg-border"

  # @param always_render [Boolean] keep it while a search is active
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(always_render: false, **attrs)
    @always_render = always_render
    @attrs = attrs
    super()
  end

  # @return [void]
  # @raise [ArgumentError] when rendered outside Command
  def view_template
    root_context
    attrs = merge_attrs({ class: CLASSES, data: { slot: "command-separator" } }, @attrs)
    attrs = with_forced(attrs, { "cmdk-separator": "", role: "separator" })
    attrs = with_forced(attrs, {}, data: { shadcn__command_always_render: "true" }) if @always_render
    div(**attrs)
  end
end

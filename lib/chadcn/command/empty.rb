# frozen_string_literal: true

# shadcn CommandEmpty: shown while no item matches the search.
#
# React renders it only while the filtered count is 0, which the server cannot know before the items render, so its markup
# is shipped in an inert `<template>` (deviation 1) and the controller mounts it. A caller `class:` REPLACES the default
# classes (shadcn does not merge them here).
#
# @example
#   render(Chadcn::Command::Empty.new { "No results found." })
class Chadcn::Command::Empty < Chadcn::Base
  include Chadcn::Command::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "py-6 text-center text-sm"

  # @param attrs [Hash] HTML attributes merged into the element; `class:` replaces the default classes
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the message
  # @return [void]
  # @raise [ArgumentError] when rendered outside Command
  def view_template(&)
    root_context
    attrs = merge_attrs({ data: { slot: "command-empty" } }, { class: CLASSES }.merge(@attrs))
    attrs = with_forced(attrs, { "cmdk-empty": "", role: "presentation" })
    template(data: { chadcn__command_target: "empty" }) { div(**attrs, &) }
  end
end

# frozen_string_literal: true

# shadcn ComboboxSeparator: a rule between groups (`div`, `role="presentation"`).
#
# @example
#   render Phlex::Shadcn::Combobox::Separator.new
class Phlex::Shadcn::Combobox::Separator < Phlex::Shadcn::Base
  include Phlex::Shadcn::Combobox::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "-mx-1 my-1 h-px bg-border"

  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template
    root_model
    data = { slot: "combobox-separator", orientation: "horizontal", shadcn__combobox_part: "separator" }
    div(**merge_attrs({ role: "presentation", class: CLASSES, data: data }, @attrs))
  end
end

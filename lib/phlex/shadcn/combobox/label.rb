# frozen_string_literal: true

# shadcn ComboboxLabel: the heading of a {Combobox::Group} (`div`, hidden from assistive technology; the group names itself with it).
#
# @example
#   render(Phlex::Shadcn::Combobox::Label.new { "Europe" })
class Phlex::Shadcn::Combobox::Label < Phlex::Shadcn::Base
  include Phlex::Shadcn::Combobox::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "px-2 py-1.5 text-xs text-muted-foreground pointer-coarse:px-3 pointer-coarse:py-2 pointer-coarse:text-sm"

  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the label text
  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template(&)
    model = root_model
    id = context[Phlex::Shadcn::Combobox::Group::CONTEXT_KEY]&.fetch(:label_id) || "#{model.id}-label-#{model.next_counter}"
    div(**merge_attrs({ id: id, aria: { hidden: "true" }, class: CLASSES, data: { slot: "combobox-label" } }, @attrs), &)
  end
end

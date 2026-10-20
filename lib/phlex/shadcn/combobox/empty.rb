# frozen_string_literal: true

# shadcn ComboboxEmpty: the "no results" live region (`div`, `role="status"`). The element always stays; its content shows only while
# no item matches (the controller keeps the content and toggles it).
#
# @example
#   render(Phlex::Shadcn::Combobox::Empty.new { "No items found." })
class Phlex::Shadcn::Combobox::Empty < Phlex::Shadcn::Base
  include Phlex::Shadcn::Combobox::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "hidden w-full justify-center py-2 text-center text-sm text-muted-foreground group-data-empty/combobox-content:flex"

  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the content shown while the list is empty
  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template(&)
    root_model
    attrs = merge_attrs({ role: "status", class: CLASSES, aria: { live: "polite", atomic: "true" },
                          data: { slot: "combobox-empty", shadcn__combobox_part: "empty" } }, @attrs)
    div(**attrs, &)
  end
end

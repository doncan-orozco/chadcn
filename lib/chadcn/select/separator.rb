# frozen_string_literal: true

# A thin horizontal rule (+div aria-hidden="true"+) between groups or items.
#
# @example
#   select.separator
class Chadcn::Select::Separator < Chadcn::Base
  include Chadcn::Select::Support

  # @return [String] Tailwind classes of the separator
  CLASSES = "pointer-events-none -mx-1 my-1 h-px bg-border"

  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String or a
  #   component instance renders that instead, receiving the part's attributes
  # @param attrs [Hash] HTML attributes merged into the element (+class+ is merged with Tailwind conflict resolution, +data+/+aria+ deep-merged, caller wins)
  # @return [void]
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield optional content of the element
  # @return [void]
  def view_template(&)
    attrs = merge_attrs({ class: CLASSES, aria: { hidden: "true" }, data: { slot: "select-separator" } }, @attrs)
    render_part(:div, @as_child, attrs, &)
  end
end

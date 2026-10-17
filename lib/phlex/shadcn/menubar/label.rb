# frozen_string_literal: true

# A non-interactive label for a group of items (+data-slot="menubar-label"+).
#
# @example
#   bar.label(inset: true) { "Edit" }
class Phlex::Shadcn::Menubar::Label < Phlex::Shadcn::Base
  include Phlex::Shadcn::Menubar::Support

  # @return [String] default Tailwind classes; the +class:+ you pass is merged on top
  CLASSES = "px-2 py-1.5 text-sm font-medium data-[inset]:pl-8"

  # @param inset [Boolean, nil] adds left padding to align with items that have an indicator (+data-inset+). +nil+ renders nothing, +false+ renders
  #   +data-inset="false"+ (which still matches +data-[inset]:pl-8+, so it pads like +true+). Default +nil+
  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String or a component instance
  #   renders that element carrying this part's attributes instead
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with {CLASSES} (yours wins Tailwind conflicts), +data+/+aria+ are deep merged
  def initialize(inset: nil, as_child: false, **attrs)
    @inset = inset
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  def view_template(&)
    attrs = merge_attrs({ class: CLASSES, data: { slot: "menubar-label", inset: inset_value(@inset) } }, @attrs)
    render_part(:div, @as_child, attrs, &)
  end
end

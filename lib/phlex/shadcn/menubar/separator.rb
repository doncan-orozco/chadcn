# frozen_string_literal: true

# A horizontal divider between items (+role="separator"+).
#
# @example
#   bar.separator
class Phlex::Shadcn::Menubar::Separator < Phlex::Shadcn::Base
  include Phlex::Shadcn::Menubar::Support

  # @return [String] default Tailwind classes; the +class:+ you pass is merged on top
  CLASSES = "-mx-1 my-1 h-px bg-border"

  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String or a component instance
  #   renders that element carrying this part's attributes instead
  # @param attrs [Hash] extra HTML attributes; +class+ is merged with {CLASSES} (yours wins Tailwind conflicts), +data+/+aria+ are deep merged
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield accepted but meaningless: a separator has no content
  # @return [void]
  def view_template(&)
    attrs = merge_attrs({ role: "separator", class: CLASSES, aria: { orientation: "horizontal" }, data: { slot: "menubar-separator" } },
                        @attrs)
    render_part(:div, @as_child, attrs, &)
  end
end

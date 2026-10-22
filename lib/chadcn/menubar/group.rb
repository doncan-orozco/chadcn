# frozen_string_literal: true

# A plain grouping of items (+role="group"+, +data-slot="menubar-group"+).
#
# @example
#   bar.group { bar.item { "Undo" }; bar.item { "Redo" } }
class Chadcn::Menubar::Group < Chadcn::Base
  include Chadcn::Menubar::Support

  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String or a component instance
  #   renders that element carrying this part's attributes instead
  # @param attrs [Hash] extra HTML attributes; +class+, +data+ and +aria+ are merged with the defaults
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  def view_template(&)
    render_part(:div, @as_child, merge_attrs({ role: "group", data: { slot: "menubar-group" } }, @attrs), &)
  end
end

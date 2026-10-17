# frozen_string_literal: true

# Groups items: a +div role="group"+ whose +aria-labelledby+ points at the id that a {Phlex::Shadcn::Select::Label} inside it takes.
# The attribute is always set, so without a Label it references an id that does not exist.
#
# @example
#   select.group { select.label { "Fruits" }; select.item(value: "apple") { "Apple" } }
class Phlex::Shadcn::Select::Group < Phlex::Shadcn::Base
  include Phlex::Shadcn::Select::Support

  # @param as_child [false, Symbol, String, Phlex::Shadcn::Base] +false+ renders the default element; a tag Symbol/String or a
  #   component instance renders that instead, receiving the part's attributes
  # @param attrs [Hash] HTML attributes merged into the element (+class+ is merged with Tailwind conflict resolution, +data+/+aria+ deep-merged, caller wins)
  # @return [void]
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the label and the items
  # @return [void]
  # @raise [ArgumentError] at render when used outside {Phlex::Shadcn::Select}
  def view_template(&)
    previous = context[Phlex::Shadcn::Select::GROUP_KEY]
    id = context[Phlex::Shadcn::Select::GROUP_KEY] = next_id("group")
    attrs = merge_attrs({ role: "group", aria: { labelledby: id }, data: { slot: "select-group" } }, @attrs)
    render_part(:div, @as_child, attrs, &)
  ensure
    context[Phlex::Shadcn::Select::GROUP_KEY] = previous
  end
end

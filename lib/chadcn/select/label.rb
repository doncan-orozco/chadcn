# frozen_string_literal: true

# Takes the id its Group points to with +aria-labelledby+ (raises outside a Group, as React does).
#
# @example
#   select.label { "Fruits" }
class Chadcn::Select::Label < Chadcn::Base
  include Chadcn::Select::Support

  # @return [String] Tailwind classes of the label
  CLASSES = "px-2 py-1.5 text-xs text-muted-foreground"

  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String or a
  #   component instance renders that instead, receiving the part's attributes
  # @param attrs [Hash] HTML attributes merged into the element (+class+ is merged with Tailwind conflict resolution, +data+/+aria+ deep-merged, caller wins)
  # @return [void]
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the label content
  # @return [void]
  # @raise [ArgumentError] at render when not inside a {Chadcn::Select::Group}
  def view_template(&)
    id = context[Chadcn::Select::GROUP_KEY] or raise ArgumentError, "#{self.class.name} must be used within a Group"
    render_part(:div, @as_child, merge_attrs({ id:, class: CLASSES, data: { slot: "select-label" } }, @attrs), &)
  end
end

# frozen_string_literal: true

# shadcn SidebarInput: the shared Input with the sidebar sizing.
#
# Rendered inside a {Phlex::Shadcn::Sidebar}; also available as `sidebar.input` on the yielded sidebar.
#
# @see Phlex::Shadcn::Sidebar
# @see Phlex::Shadcn::Input
class Phlex::Shadcn::Sidebar::Input < Phlex::Shadcn::Base
  # Tailwind classes merged onto the shared Input (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = "h-8 w-full bg-background shadow-none"

  # @param type [String, Symbol, nil] the `input` type attribute (default: nil)
  # @param attrs [Hash] attributes forwarded to {Phlex::Shadcn::Input}; `class:` is tailwind-merged over the defaults
  def initialize(type: nil, **attrs)
    @type = type
    @attrs = attrs
    super()
  end

  # Renders the shared {Phlex::Shadcn::Input} with the sidebar slot data attributes.
  #
  # @return [void]
  def view_template
    attrs = canonical_attrs(@attrs).except(:class)
    data = { slot: "sidebar-input", sidebar: "input" }.merge(attrs[:data] || {})
    render Phlex::Shadcn::Input.new(type: @type, class: cn(CLASSES, @attrs[:class]), **attrs.merge(data:))
  end
end

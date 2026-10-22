# frozen_string_literal: true

# shadcn SidebarInput: the shared Input with the sidebar sizing.
#
# Rendered inside a {Chadcn::Sidebar}; also available as `sidebar.input` on the yielded sidebar.
#
# @see Chadcn::Sidebar
# @see Chadcn::Input
class Chadcn::Sidebar::Input < Chadcn::Base
  # Tailwind classes merged onto the shared Input (verbatim from shadcn/ui).
  #
  # @api private
  CLASSES = "h-8 w-full bg-background shadow-none"

  # @param type [String, Symbol, nil] the `input` type attribute (default: nil)
  # @param attrs [Hash] attributes forwarded to {Chadcn::Input}; `class:` is tailwind-merged over the defaults
  def initialize(type: nil, **attrs)
    @type = type
    @attrs = attrs
    super()
  end

  # Renders the shared {Chadcn::Input} with the sidebar slot data attributes.
  #
  # @return [void]
  def view_template
    attrs = canonical_attrs(@attrs).except(:class)
    data = { slot: "sidebar-input", sidebar: "input" }.merge(attrs[:data] || {})
    render Chadcn::Input.new(type: @type, class: cn(CLASSES, @attrs[:class]), **attrs.merge(data:))
  end
end

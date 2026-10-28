# frozen_string_literal: true

# shadcn DrawerDescription. Marks the drawer as described so Content can emit aria-describedby.
#
# Accessible description (`p`); makes Content emit `aria-describedby`.
class Chadcn::Drawer::Description < Chadcn::Base
  include Chadcn::Drawer::Support

  # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the description content
  # @return [void]
  # @raise [ArgumentError] when rendered outside Drawer
  def view_template(&)
    root = root_context
    root[:description_present] = true
    attrs = merge_attrs({ id: root[:description_id], class: "text-sm text-muted-foreground", data: { slot: "drawer-description" } }, @attrs)
    render_part(:p, @as_child, attrs, &)
  end
end

# frozen_string_literal: true

# What the drawer parts share: the render context pushed by Drawer and the as_child switch.
#
# @api private
module Chadcn::Drawer::Support
  private

  def root_context
    context[Chadcn::Drawer::ROOT_KEY] or raise ArgumentError, "#{self.class.name} must be used within Drawer"
  end

  def state_of(root) = root[:open] ? "open" : "closed"

  def bool(value) = value ? "true" : "false"

  def render_part(tag_name, as_child, attrs, &)
    return render_as_child(as_child, **attrs, &) if as_child

    tag(tag_name, **attrs, &)
  end
end

# frozen_string_literal: true

using Chadcn::Values::Refinements

# What the tabs parts share: the render context pushed by Tabs.
#
# @api private
module Chadcn::Tabs::Support
  private

  def root_context
    context[Chadcn::Tabs::ROOT_KEY] or raise ArgumentError, "#{self.class.name} must be used within Tabs"
  end

  def render_part(tag_name, as_child, attrs, &)
    return render_as_child(as_child, **attrs, &) if as_child

    tag(tag_name, **attrs, &)
  end

  def join_style(*parts) = parts.map { |part| style_string(part) }.reject_blank.join("; ").unless_blank
end

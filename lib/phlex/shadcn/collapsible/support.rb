# frozen_string_literal: true

# What the collapsible parts share: the render context pushed by Collapsible.
#
# @api private
module Phlex::Shadcn::Collapsible::Support
  private

  def root_context
    context[Phlex::Shadcn::Collapsible::ROOT_KEY] or raise ArgumentError, "#{self.class.name} must be used within Collapsible"
  end

  def state_of(root) = root[:open] ? "open" : "closed"

  def disabled_data(root) = root[:disabled] ? "" : nil
end

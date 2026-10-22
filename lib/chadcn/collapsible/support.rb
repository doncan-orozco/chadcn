# frozen_string_literal: true

# What the collapsible parts share: the render context pushed by Collapsible.
#
# @api private
module Chadcn::Collapsible::Support
  private

  def root_context
    context[Chadcn::Collapsible::ROOT_KEY] or raise ArgumentError, "#{self.class.name} must be used within Collapsible"
  end

  def state_of(root) = root[:open] ? "open" : "closed"

  def disabled_data(root) = root[:disabled] ? "" : nil
end

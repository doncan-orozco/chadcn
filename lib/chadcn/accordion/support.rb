# frozen_string_literal: true

# What the accordion parts share: the render context pushed by Accordion and Accordion::Item.
#
# @api private
module Chadcn::Accordion::Support
  private

  def root_context
    context[Chadcn::Accordion::ROOT_KEY] or raise ArgumentError, "#{self.class.name} must be used within Accordion"
  end

  def item_context
    context[Chadcn::Accordion::ITEM_KEY] or raise ArgumentError, "#{self.class.name} must be used within Accordion::Item"
  end

  def state_of(item) = item[:open] ? "open" : "closed"

  def disabled_data(item) = item[:disabled] ? "" : nil
end

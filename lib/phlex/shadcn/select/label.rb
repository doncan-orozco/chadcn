# frozen_string_literal: true

# Radix SelectLabel: takes the id its Group points to with aria-labelledby (React throws outside a Group, sel:L811).
class Phlex::Shadcn::Select::Label < Phlex::Shadcn::Base
  include Phlex::Shadcn::Select::Support

  CLASSES = "px-2 py-1.5 text-xs text-muted-foreground"

  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    id = context[Phlex::Shadcn::Select::GROUP_KEY] or raise ArgumentError, "#{self.class.name} must be used within a Group"
    render_part(:div, @as_child, merge_attrs({ id:, class: CLASSES, data: { slot: "select-label" } }, @attrs), &)
  end
end

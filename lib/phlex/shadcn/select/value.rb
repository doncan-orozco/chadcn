# frozen_string_literal: true

# Radix SelectValue. className and style are destructured and dropped (sel:L244); the span shows the placeholder, its own
# block, or a copy of the children of the selected item (Radix portals the ItemText children into it, sel:L959).
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::Select::Value < Phlex::Shadcn::Base
  include Phlex::Shadcn::Select::Support

  def initialize(placeholder: "", **attrs)
    @placeholder = placeholder
    @attrs = attrs.except(:class, :style)
    super()
  end

  def view_template(&block)
    return if collecting?

    children = capture(&block).unless_blank if block
    attrs = merge_attrs({
                          style: "pointer-events: none;",
                          data: { slot: "select-value", shadcn__select_placeholder: @placeholder, shadcn__select_children: children }
                        }, @attrs)
    span(**attrs) { content(children) }
  end

  private

  def content(children)
    return plain(@placeholder) if blank_value?
    return raw(safe(children)) if children

    item = select_state[:known].find { |known| known[:value] == select_state[:value] }
    raw(safe(item[:html])) if item
  end
end

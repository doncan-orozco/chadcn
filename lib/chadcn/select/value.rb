# frozen_string_literal: true

using Chadcn::Values::Refinements

# Shows the selected item's content, or the placeholder while no value is selected (the span shows the placeholder, its own
# block, or a copy of the selected item's HTML children). +class+ and +style+ are dropped. +as_child:+ is not offered and is
# rendered as a literal HTML attribute.
# Renders nothing during the root's collect pass. When the selected value matches no registered item the span stays empty.
#
# @example
#   select.value(placeholder: "Pick a fruit")
class Chadcn::Select::Value < Chadcn::Base
  include Chadcn::Select::Support

  # @param placeholder [String] text shown while the value is blank
  # @param attrs [Hash] HTML attributes for the span; +class+ and +style+ keys are discarded
  # @return [void]
  def initialize(placeholder: "", **attrs)
    @placeholder = placeholder
    @attrs = attrs.except(:class, :style)
    super()
  end

  # @yield optional content that replaces the copy of the selected item's children; while the value is blank the placeholder
  #   takes priority over the block
  # @return [void]
  # @raise [ArgumentError] at render when used outside {Chadcn::Select}
  def view_template(&block)
    return if collecting?

    children = capture(&block).unless_blank if block
    attrs = merge_attrs({
                          style: "pointer-events: none;",
                          data: { slot: "select-value", chadcn__select_placeholder: @placeholder, chadcn__select_children: children }
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

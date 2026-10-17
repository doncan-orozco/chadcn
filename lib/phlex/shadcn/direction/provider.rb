# frozen_string_literal: true

# DirectionProvider: pushes the direction into the render context for consumers; emits no markup.
#
# @example
#   render Phlex::Shadcn::Direction::Provider.new(direction: :rtl) do
#     render Phlex::Shadcn::NavigationMenu.new { |menu| menu.list { menu.item { plain "Docs" } } } # renders dir="rtl"
#   end
# @see Phlex::Shadcn::Direction
class Phlex::Shadcn::Direction::Provider < Phlex::Shadcn::Base
  # `direction:` wins over `dir:`; both nil leaves the inherited direction untouched for the block.
  #
  # @param dir [String, Symbol, nil] `ltr` or `rtl` (default: nil)
  # @param direction [String, Symbol, nil] same as `dir:`, takes precedence (default: nil)
  # @raise [ArgumentError] when the value is not `ltr` or `rtl`
  def initialize(dir: nil, direction: nil)
    value = (direction.nil? ? dir : direction)&.to_s
    unless value.nil? || Phlex::Shadcn::Direction::VALUES.include?(value)
      raise ArgumentError, "direction must be ltr or rtl, got #{value.inspect}"
    end

    @value = value
    super()
  end

  # Sets the direction in the render context for the block, then restores the previous one. Emits no markup.
  #
  # @yieldparam provider [Phlex::Shadcn::Direction::Provider] the provider itself
  # @return [void]
  def view_template
    previous = context[Phlex::Shadcn::Direction::KEY]
    context[Phlex::Shadcn::Direction::KEY] = @value
    yield self if block_given?
  ensure
    context[Phlex::Shadcn::Direction::KEY] = previous
  end
end

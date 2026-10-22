# frozen_string_literal: true

# DirectionProvider: pushes the direction into the render context for consumers; emits no markup.
#
# @example
#   render Chadcn::Direction::Provider.new(direction: :rtl) do
#     render Chadcn::NavigationMenu.new { |menu| menu.list { menu.item { plain "Docs" } } } # renders dir="rtl"
#   end
# @see Chadcn::Direction
class Chadcn::Direction::Provider < Chadcn::Base
  # `direction:` wins over `dir:`; both nil leaves the inherited direction (an outer provider's, or none) untouched for the block.
  #
  # @param dir [String, Symbol, nil] `ltr` or `rtl` (default: nil)
  # @param direction [String, Symbol, nil] same as `dir:`, takes precedence (default: nil)
  # @raise [ArgumentError] when the value is not `ltr` or `rtl`
  def initialize(dir: nil, direction: nil)
    value = (direction.nil? ? dir : direction)&.to_s
    unless value.nil? || Chadcn::Direction::VALUES.include?(value)
      raise ArgumentError, "direction must be ltr or rtl, got #{value.inspect}"
    end

    @value = value
    super()
  end

  # Sets the direction in the render context for the block, then restores the previous one. Emits no markup.
  #
  # @yieldparam provider [Chadcn::Direction::Provider] the provider itself
  # @return [void]
  def view_template
    previous = context[Chadcn::Direction::KEY]
    context[Chadcn::Direction::KEY] = @value unless @value.nil?
    yield self if block_given?
  ensure
    context[Chadcn::Direction::KEY] = previous
  end
end

# frozen_string_literal: true

# DirectionProvider: pushes the direction into the render context for consumers; emits no markup.
class Phlex::Shadcn::Direction::Provider < Phlex::Shadcn::Base
  def initialize(dir: nil, direction: nil)
    value = (direction.nil? ? dir : direction)&.to_s
    unless value.nil? || Phlex::Shadcn::Direction::VALUES.include?(value)
      raise ArgumentError, "direction must be ltr or rtl, got #{value.inspect}"
    end

    @value = value
    super()
  end

  def view_template
    previous = context[Phlex::Shadcn::Direction::KEY]
    context[Phlex::Shadcn::Direction::KEY] = @value
    yield self if block_given?
  ensure
    context[Phlex::Shadcn::Direction::KEY] = previous
  end
end

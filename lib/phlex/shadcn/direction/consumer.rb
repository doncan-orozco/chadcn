# frozen_string_literal: true

# Mixin for parts that read the direction (Radix useDirection).
module Phlex::Shadcn::Direction::Consumer
  private

  def use_direction(local_dir = nil)
    Phlex::Shadcn::Direction.use_direction(context, local_dir)
  end
end

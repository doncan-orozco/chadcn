# frozen_string_literal: true

# Mixin for parts that read the direction (Radix useDirection).
#
# Including it adds the private `use_direction(local_dir = nil)` to a component.
#
# @see Chadcn::Direction.use_direction
module Chadcn::Direction::Consumer
  private

  # @param local_dir [String, Symbol, nil] direction set on the component itself, wins when present (default: nil)
  # @return [String] `"ltr"` or `"rtl"`
  def use_direction(local_dir = nil)
    Chadcn::Direction.use_direction(context, local_dir)
  end
end

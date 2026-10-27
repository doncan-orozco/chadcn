# frozen_string_literal: true

# What the carousel parts share: the render context pushed by Carousel (useCarousel in the oracle).
#
# @api private
module Chadcn::Carousel::Support
  private

  def orientation
    root = context[Chadcn::Carousel::ROOT_KEY] or raise ArgumentError, "useCarousel must be used within a <Carousel />"
    root[:orientation]
  end

  def horizontal? = orientation == "horizontal"
end

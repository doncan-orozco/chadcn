# frozen_string_literal: true

# shadcn CarouselNext: an outline icon Button. Its content is fixed (a block is ignored, like React's explicit children).
class Chadcn::Carousel::Next < Chadcn::Base
  include Chadcn::Carousel::Arrow

  ARROW = {
    slot: "carousel-next", target: "next", action: "click->chadcn--carousel#scrollNext", icon: "arrow-right",
    placement: {
      "horizontal" => "top-1/2 -right-12 -translate-y-1/2",
      "vertical" => "-bottom-12 left-1/2 -translate-x-1/2 rotate-90"
    }.freeze
  }.freeze
  private_constant :ARROW

  # @param variant [String, Symbol] any Button variant
  # @param size [String, Symbol] any Button size
  # @param label [String] the screen-reader text
  # @param attrs [Hash] HTML attributes merged onto the button; a `disabled:` (true or false) is final, the controller never touches it
  def initialize(label: "Next slide", **) = super

  private

  def arrow = ARROW
end

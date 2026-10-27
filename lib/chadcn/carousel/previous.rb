# frozen_string_literal: true

# shadcn CarouselPrevious: an outline icon Button. Its content is fixed (a block is ignored, like React's explicit children).
class Chadcn::Carousel::Previous < Chadcn::Base
  include Chadcn::Carousel::Support

  PLACEMENT = {
    "horizontal" => "top-1/2 -left-12 -translate-y-1/2",
    "vertical" => "-top-12 left-1/2 -translate-x-1/2 rotate-90"
  }.freeze

  # @param variant [String, Symbol] any Button variant
  # @param size [String, Symbol] any Button size
  # @param attrs [Hash] HTML attributes merged onto the button; a `disabled:` (true or false) is final, the controller never touches it
  def initialize(variant: "outline", size: "icon", **attrs)
    @variant = variant
    @size = size
    @attrs = attrs
    super()
  end

  # @return [void]
  def view_template
    attrs = merge_attrs({
                          class: [ "absolute size-8 rounded-full", PLACEMENT.fetch(orientation) ],
                          disabled: true,
                          data: { slot: "carousel-previous", chadcn__carousel_target: "previous",
                                  action: "click->chadcn--carousel#scrollPrev" }
                        }, @attrs.compact)
    attrs[:data] = attrs[:data].merge(chadcn__carousel_locked: "true") if @attrs.key?(:disabled) && !@attrs[:disabled].nil?
    render(Chadcn::Button.new(variant: @variant, size: @size, **attrs)) do
      render Chadcn::Icon.new("arrow-left")
      span(class: "sr-only") { "Previous slide" }
    end
  end
end

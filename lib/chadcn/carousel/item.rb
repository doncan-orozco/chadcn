# frozen_string_literal: true

# shadcn CarouselItem: one slide.
class Chadcn::Carousel::Item < Chadcn::Base
  include Chadcn::Carousel::Support

  # @param attrs [Hash] HTML attributes merged onto the slide (a caller `role:` wins)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the slide content
  # @return [void]
  def view_template(&)
    div(**merge_attrs({
                        role: "group", aria: { roledescription: "slide" }, data: { slot: "carousel-item" },
                        class: [ "min-w-0 shrink-0 grow-0 basis-full", (horizontal? ? "pl-4" : "pt-4") ]
                      }, @attrs), &)
  end
end

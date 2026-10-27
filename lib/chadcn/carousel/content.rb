# frozen_string_literal: true

# shadcn CarouselContent: the overflow-hidden viewport (no caller attributes) around the flex container, which takes `class:`
# and `**attrs`.
class Chadcn::Carousel::Content < Chadcn::Base
  include Chadcn::Carousel::Support

  # @param attrs [Hash] HTML attributes merged onto the inner container element
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the slides
  # @return [void]
  def view_template(&)
    attrs = merge_attrs({
                          class: [ "flex", (horizontal? ? "-ml-4" : "-mt-4 flex-col") ],
                          data: { chadcn__carousel_target: "container" }
                        }, @attrs)
    div(class: "overflow-hidden", data: { slot: "carousel-content", chadcn__carousel_target: "viewport" }) do
      div(**attrs, &)
    end
  end
end

# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::CarouselTest < Chadcn::TestCase
  Carousel = Chadcn::Carousel

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def carousel(root: {}, content: {}, item: {}, previous: {}, nxt: {})
    render_view do
      render(Carousel.new(**root)) do
        render(Carousel::Content.new(**content)) do
          render(Carousel::Item.new(**item)) { "1" }
          render(Carousel::Item.new) { "2" }
        end
        render(Carousel::Previous.new(**previous))
        render(Carousel::Next.new(**nxt))
      end
    end
  end

  test "root, viewport, container and slides" do
    doc = fragment(carousel(root: { class: "w-full max-w-xs", id: "c" }, content: { class: "-ml-1" }, item: { class: "md:basis-1/2" }))
    root = doc.at_css("[data-slot=carousel]")
    viewport = doc.at_css("[data-slot=carousel-content]")

    assert_equal "relative w-full max-w-xs", root["class"]
    assert_equal "region", root["role"]
    assert_equal "carousel", root["aria-roledescription"]
    assert_equal "c", root["id"]
    assert_equal "horizontal", root["data-chadcn--carousel-orientation-value"]
    assert_equal "{}", root["data-chadcn--carousel-opts-value"]
    assert_equal "keydown->chadcn--carousel#keydown:capture", root["data-action"]
    assert_equal "overflow-hidden", viewport["class"]
    assert_equal "flex -ml-1", viewport.at_css("> div")["class"]
    slides = doc.css("[data-slot=carousel-item]")

    assert_equal 2, slides.size
    assert_equal "slide", slides.first["aria-roledescription"]
    assert_equal "group", slides.first["role"]
    assert_equal "min-w-0 shrink-0 grow-0 basis-full pl-4 md:basis-1/2", slides.first["class"]
  end

  test "vertical orientation switches the part classes" do
    doc = fragment(carousel(root: { orientation: :vertical }))

    assert_equal "flex -mt-4 flex-col", doc.at_css("[data-slot=carousel-content] > div")["class"]
    assert_includes doc.at_css("[data-slot=carousel-item]")["class"], "pt-4"
    assert_includes doc.at_css("[data-slot=carousel-previous]")["class"], "-top-12 left-1/2 -translate-x-1/2 rotate-90"
    assert_includes doc.at_css("[data-slot=carousel-next]")["class"], "-bottom-12 left-1/2 -translate-x-1/2 rotate-90"
  end

  test "previous and next are disabled outline icon buttons with a fixed label" do
    doc = fragment(carousel(previous: { class: "extra" }))
    previous = doc.at_css("[data-slot=carousel-previous]")
    following = doc.at_css("[data-slot=carousel-next]")

    assert_equal "", previous["disabled"]
    assert_equal "outline", previous["data-variant"]
    assert_equal "icon", previous["data-size"]
    assert_includes previous["class"], "absolute size-8 rounded-full top-1/2 -left-12 -translate-y-1/2 extra"
    assert_includes following["class"], "top-1/2 -right-12 -translate-y-1/2"
    assert_equal "Previous slide", previous.at_css(".sr-only").text
    assert_equal "Next slide", following.at_css(".sr-only").text
    assert_equal "click->chadcn--carousel#scrollPrev", previous["data-action"]
  end

  test "a caller disabled value is final and locked from the controller" do
    doc = fragment(carousel(previous: { disabled: false }, nxt: { disabled: true }))
    previous = doc.at_css("[data-slot=carousel-previous]")

    assert_nil previous["disabled"]
    assert_equal "true", previous["data-chadcn--carousel-locked"]
    assert_equal "", doc.at_css("[data-slot=carousel-next]")["disabled"]
  end

  test "variant and size accept strings and symbols, and a caller data-action is added" do
    doc = fragment(carousel(previous: { variant: :ghost, size: :icon_lg, data: { action: "click->x#y" } }))
    previous = doc.at_css("[data-slot=carousel-previous]")

    assert_equal "ghost", previous["data-variant"]
    assert_equal "icon-lg", previous["data-size"]
    assert_equal "click->chadcn--carousel#scrollPrev click->x#y", previous["data-action"]
  end

  test "opts are serialized camelCase with axis left to the orientation" do
    doc = fragment(carousel(root: { opts: { start_index: 1, "dragFree" => true, containScroll: false,
                                            breakpoints: { "(min-width: 768px)" => { align: :start } } } }))
    opts = JSON.parse(doc.at_css("[data-slot=carousel]")["data-chadcn--carousel-opts-value"])

    assert_equal({ "startIndex" => 1, "dragFree" => true, "containScroll" => false, "breakpoints" => { "(min-width: 768px)" => { "align" => "start" } } }, opts)
  end

  test "invalid values raise" do
    assert_raises(ArgumentError) { Carousel.new(orientation: "diagonal") }
    assert_raises(ArgumentError) { Carousel.new(opts: { align: "middle" }) }
    assert_raises(ArgumentError) { Carousel.new(opts: { slides_to_scroll: 0 }) }
    assert_raises(ArgumentError) { Carousel.new(plugins: []) }
    assert_raises(ArgumentError) { Carousel.new(set_api: -> { }) }
  end

  test "targets, actions and merged caller data" do
    doc = fragment(carousel(root: { data: { action: "click->x#y", foo: "bar" } }, content: { data: { baz: "1" }, id: "inner" }, nxt: { class: "n" }))
    root = doc.at_css("[data-slot=carousel]")
    viewport = doc.at_css("[data-slot=carousel-content]")
    inner = viewport.at_css("> div")

    assert_equal "chadcn--carousel", root["data-controller"]
    assert_equal "keydown->chadcn--carousel#keydown:capture click->x#y", root["data-action"]
    assert_equal "bar", root["data-foo"]
    assert_equal "horizontal", root["data-chadcn--carousel-orientation-value"]
    assert_equal "viewport", viewport["data-chadcn--carousel-target"]
    assert_nil viewport["id"]
    assert_nil viewport["data-baz"]
    assert_equal "inner", inner["id"]
    assert_equal "1", inner["data-baz"]
    assert_equal "previous", doc.at_css("[data-slot=carousel-previous]")["data-chadcn--carousel-target"]
    assert_equal "next", doc.at_css("[data-slot=carousel-next]")["data-chadcn--carousel-target"]
    assert_equal "click->chadcn--carousel#scrollNext", doc.at_css("[data-slot=carousel-next]")["data-action"]
  end

  test "an item caller role wins" do
    doc = fragment(carousel(item: { role: "listitem" }))

    assert_equal "listitem", doc.css("[data-slot=carousel-item]").first["role"]
    assert_equal "group", doc.css("[data-slot=carousel-item]").last["role"]
  end

  test "previous and next take a label" do
    doc = fragment(carousel(previous: { label: "Anterior" }, nxt: { label: "Siguiente" }))

    assert_equal "Anterior", doc.at_css("[data-slot=carousel-previous] .sr-only").text
    assert_equal "Siguiente", doc.at_css("[data-slot=carousel-next] .sr-only").text
    assert_nil doc.at_css("[data-slot=carousel-next]")["label"]
  end

  test "content outside a carousel raises" do
    assert_raises(ArgumentError) { render_view { render(Carousel::Content.new) { "x" } } }
  end

  test "non-boolean and non-enum opts raise, symbols and breakpoints normalize" do
    assert_raises(ArgumentError) { Carousel.new(opts: { loop: "yes" }) }
    assert_raises(ArgumentError) { Carousel.new(opts: "loop") }
    assert_equal({ "align" => "end" }, JSON.parse(fragment(render_view { render(Carousel.new(opts: { align: :end })) }).at_css("[data-slot=carousel]")["data-chadcn--carousel-opts-value"]))
  end

  test "parts outside a carousel raise" do
    error = assert_raises(ArgumentError) { render_view { render(Carousel::Item.new) } }

    assert_match(%r{useCarousel must be used within a <Carousel />}, error.message)
  end

  test "only the four parts generate helpers" do
    assert_equal %i[content item next previous], (Carousel.public_instance_methods(false) - %i[view_template]).sort
  end

  test "every spec helper renders like the explicit part" do
    helpers = render_view do
      render(Carousel.new) do |c|
        c.content(class: "-ml-1") do
          c.item { "1" }
        end
        c.previous(variant: "ghost")
        c.next
      end
    end
    explicit = render_view do
      render(Carousel.new) do
        render(Carousel::Content.new(class: "-ml-1")) { render(Carousel::Item.new) { "1" } }
        render(Carousel::Previous.new(variant: "ghost"))
        render(Carousel::Next.new)
      end
    end

    assert_equal explicit, helpers
  end
end

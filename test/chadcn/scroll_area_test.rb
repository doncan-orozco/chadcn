# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::ScrollAreaTest < Chadcn::TestCase
  ScrollArea = Chadcn::ScrollArea

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def area(**props, &block)
    fragment(render_view do
      render(ScrollArea.new(**props)) do |scroll_area|
        block ? instance_exec(scroll_area, &block) : plain("content")
      end
    end)
  end

  test "root renders slot, dir, merged class, style and passthrough attrs" do
    root = area(class: "h-72 static", id: "tags", aria: { label: "Tags" }, style: "color: red").at_css("[data-slot=scroll-area]")

    assert_equal "ltr", root["dir"]
    assert_equal "tags", root["id"]
    assert_equal "Tags", root["aria-label"]
    assert_equal "h-72 static", root["class"]
    assert_equal "position: relative; --radix-scroll-area-corner-width: 0px; --radix-scroll-area-corner-height: 0px; color: red;",
                 root["style"]
    assert_equal "hover", root["data-chadcn--scroll-area-type-value"]
  end

  test "viewport wraps the content and enables only the axes with a scrollbar" do
    doc = area(type: :always)
    viewport = doc.at_css("[data-slot=scroll-area-viewport]")

    assert_equal "overflow-x: hidden; overflow-y: scroll;", viewport["style"]
    assert_equal "content", viewport.at_css("div").text

    both = area { |scroll_area| scroll_area.scroll_bar(orientation: :horizontal) }

    assert_equal "overflow-x: scroll; overflow-y: scroll;", both.at_css("[data-slot=scroll-area-viewport]")["style"]
  end

  test "scrollbars and thumbs wait in templates with the oracle classes" do
    doc = area { |scroll_area| scroll_area.scroll_bar(orientation: "horizontal", force_mount: true, class: "h-4", id: "bar") }
    bars = doc.css("template[data-chadcn--scroll-area-target=scrollbar]")
    horizontal = bars.first.at_css("template").parent

    assert_equal 2, bars.size
    assert_equal "true", bars.first["data-chadcn--scroll-area-force-mount"]
    assert_equal "bar", horizontal["id"]
    assert_equal "scroll-area-scrollbar", horizontal["data-slot"]
    assert_includes horizontal["class"], "h-4"
    assert_includes horizontal["class"], "flex-col"
    assert_includes bars.last.at_css("div")["class"], "w-2.5"
    assert_includes bars.last.at_css("template").inner_html, "scroll-area-thumb"
  end

  test "rejects unknown options and as_child" do
    assert_raises(ArgumentError) { ScrollArea.new(type: "nope") }
    assert_raises(ArgumentError) { ScrollArea.new(as_child: true) }
    assert_raises(ArgumentError) { ScrollArea::ScrollBar.new(orientation: "diagonal") }
    assert_raises(ArgumentError) { render_view { render ScrollArea::ScrollBar.new } }
  end

  test "dx helper renders the same html as the explicit class" do
    helper = render_view { render(ScrollArea.new) { |scroll_area| scroll_area.scroll_bar(orientation: "horizontal") } }
    explicit = render_view { render(ScrollArea.new) { render ScrollArea::ScrollBar.new(orientation: "horizontal") } }

    assert_equal explicit, helper
    assert_respond_to ScrollArea.new, :scroll_bar
  end

  test "scroll_hide_delay and type reach the controller values" do
    root = area(type: "scroll", scroll_hide_delay: 250).at_css("[data-slot=scroll-area]")

    assert_equal "250", root["data-chadcn--scroll-area-scroll-hide-delay-value"]
    assert_equal "scroll", root["data-chadcn--scroll-area-type-value"]
    assert_equal "600", area.at_css("[data-slot=scroll-area]")["data-chadcn--scroll-area-scroll-hide-delay-value"]
    assert_predicate ScrollArea::TYPES, :any?
    ScrollArea::TYPES.each { |type| assert_equal type, area(type:).at_css("[data-slot=scroll-area]")["data-chadcn--scroll-area-type-value"] }
  end

  test "dir wins over the direction provider and the provider wins over ltr" do
    local = fragment(render_view do
      render(Chadcn::Direction::Provider.new(dir: "rtl")) { render(ScrollArea.new(dir: "ltr")) { plain "x" } }
    end)
    inherited = fragment(render_view do
      render(Chadcn::Direction::Provider.new(dir: "rtl")) { render(ScrollArea.new) { plain "x" } }
    end)

    assert_equal "ltr", local.at_css("[data-slot=scroll-area]")["dir"]
    assert_equal "rtl", inherited.at_css("[data-slot=scroll-area]")["dir"]
  end

  test "scrollbar defaults to vertical, without force mount, and merges caller attrs" do
    doc = area { |scroll_area| scroll_area.scroll_bar(data: { testid: "bar" }, aria: { hidden: true }) }
    bars = doc.css("template[data-chadcn--scroll-area-target=scrollbar]")
    bar = bars.first.at_css("[data-slot=scroll-area-scrollbar]")

    assert_equal "vertical", bar["data-orientation"]
    assert_equal "bar", bar["data-testid"]
    assert_equal "true", bar["aria-hidden"]
    assert_nil bars.first["data-chadcn--scroll-area-force-mount"]
    assert_equal %w[vertical horizontal], ScrollArea::ScrollBar::ORIENTATIONS
  end

  test "scrollbar rejects as_child" do
    assert_raises(ArgumentError) { ScrollArea::ScrollBar.new(as_child: true) }
  end
end

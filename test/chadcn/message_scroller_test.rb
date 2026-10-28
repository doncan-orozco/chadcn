# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::MessageScrollerTest < Chadcn::TestCase
  MessageScroller = Chadcn::MessageScroller
  HOST = "[data-controller~='chadcn--message-scroller']"
  BUTTON = "[data-slot=message-scroller-button]"

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def transcript(provider: {}, root: {}, viewport: {}, content: {}, button: {})
    render_view do
      render(MessageScroller::Provider.new(**provider)) do
        render(MessageScroller.new(**root)) do
          render(MessageScroller::Viewport.new(**viewport)) do
            render(MessageScroller::Content.new(**content)) { plain "rows" }
          end
          render(MessageScroller::Button.new(**button))
        end
      end
    end
  end

  test "the provider renders one display-contents host with the controller values and nothing else" do
    host = fragment(transcript(provider: { auto_scroll: true, default_scroll_position: :last_anchor, scroll_margin: 12 })).at_css(HOST)

    assert_equal "display: contents", host["style"]
    assert_equal "chadcn--message-scroller", host["data-controller"]
    assert_equal "true", host["data-chadcn--message-scroller-auto-scroll-value"]
    assert_equal "last-anchor", host["data-chadcn--message-scroller-default-scroll-position-value"]
    assert_equal "8", host["data-chadcn--message-scroller-scroll-edge-threshold-value"]
    assert_equal "64", host["data-chadcn--message-scroller-scroll-previous-item-peek-value"]
    assert_equal "12", host["data-chadcn--message-scroller-scroll-margin-value"]
    assert_equal "false", host["data-chadcn--message-scroller-track-visibility-value"]
    assert_nil host["class"]
    assert_nil host["data-slot"]
  end

  test "an unknown opening position or direction raises" do
    assert_raises(ArgumentError) { MessageScroller::Provider.new(default_scroll_position: "middle") }
    assert_raises(ArgumentError) { MessageScroller::Button.new(direction: "up") }
  end

  def slot_parts
    doc = fragment(transcript)
    %w[message-scroller message-scroller-viewport message-scroller-content].map { |slot| doc.at_css("[data-slot=#{slot}]") }
  end

  test "the frame carries its slot, pending-scroll marker and layout classes" do
    root, = slot_parts

    assert_equal "", root["data-pending-scroll"]
    %w[relative size-full overflow-hidden].each { |token| assert_includes root["class"], token }
  end

  test "the viewport is a labelled focusable region hidden while the scroll is pending" do
    _, viewport, = slot_parts

    assert_equal %w[region Messages 0], [ viewport["role"], viewport["aria-label"], viewport["tabindex"] ]
    assert_equal "", viewport["data-pending-scroll"]
    assert_includes viewport["class"], "data-pending-scroll:invisible"
  end

  test "the content is a log announcing additions with the default gap" do
    _, _, content = slot_parts

    assert_equal %w[log additions], [ content["role"], content["aria-relevant"] ]
    assert_includes content["class"], "gap-8"
  end

  test "a start opening position renders no pending-scroll attribute and outside a provider neither" do
    start = fragment(transcript(provider: { default_scroll_position: "start" }))

    assert_nil start.at_css("[data-slot=message-scroller]")["data-pending-scroll"]
    assert_nil start.at_css("[data-slot=message-scroller-viewport]")["data-pending-scroll"]

    alone = fragment(render_view { render(MessageScroller.new) { |s| s.viewport { "x" } } })

    assert_nil alone.at_css("[data-slot=message-scroller]")["data-pending-scroll"]
    assert_nil alone.at_css("[data-slot=message-scroller-viewport]")["data-pending-scroll"]
  end

  test "caller attributes override the defaults and class wins Tailwind conflicts" do
    doc = fragment(transcript(root: { class: "overflow-visible border", id: "frame" },
                              viewport: { role: "feed", aria: { label: "Chat" }, tab_index: -1, class: "px-2" },
                              content: { role: "list", "aria-relevant": "all", class: "gap-4 p-4" }))
    root = doc.at_css("[data-slot=message-scroller]")
    viewport = doc.at_css("[data-slot=message-scroller-viewport]")
    content = doc.at_css("[data-slot=message-scroller-content]")

    assert_equal "frame", root["id"]
    assert_includes root["class"], "overflow-visible"
    refute_includes root["class"], "overflow-hidden"
    assert_equal %w[feed Chat -1], [ viewport["role"], viewport["aria-label"], viewport["tabindex"] ]
    assert_includes viewport["class"], "px-2"
    assert_equal %w[list all], [ content["role"], content["aria-relevant"] ]
    assert_includes content["class"], "gap-4"
    refute_includes content["class"], "gap-8"
  end

  test "the viewport wires the scroll events and carries preserve_scroll_on_prepend only when false" do
    viewport = fragment(transcript).at_css("[data-slot=message-scroller-viewport]")

    assert_equal "viewport", viewport["data-chadcn--message-scroller-target"]
    assert_includes viewport["data-action"], "scroll->chadcn--message-scroller#syncAfterScroll"
    assert_includes viewport["data-action"], "wheel->chadcn--message-scroller#userScrollIntent:passive"
    assert_nil viewport["data-chadcn--message-scroller-preserve-scroll-on-prepend"]

    off = fragment(transcript(viewport: { preserve_scroll_on_prepend: false })).at_css("[data-slot=message-scroller-viewport]")

    assert_equal "false", off["data-chadcn--message-scroller-preserve-scroll-on-prepend"]
  end

  test "the content always ends with the hidden spacer" do
    doc = fragment(transcript)
    spacer = doc.at_css("[data-message-scroller-spacer]")

    assert_equal spacer.to_s, doc.at_css("[data-slot=message-scroller-content]").element_children.last.to_s
    assert_equal "true", spacer["aria-hidden"]
    assert_equal "", spacer["data-message-scroller-spacer"]
    assert_equal "", spacer["hidden"]
    assert_nil spacer["class"]
    assert_equal "spacer", spacer["data-chadcn--message-scroller-target"]

    styled = fragment(transcript(content: { spacer_class_name: "bg-red-500" })).at_css("[data-message-scroller-spacer]")

    assert_equal "bg-red-500", styled["class"]
  end

  test "items carry message id, anchor flag, slot and merged classes" do
    doc = fragment(render_view do
      render(MessageScroller::Item.new(message_id: "m1", scroll_anchor: true, class: "shrink rounded-md")) { "a" }
      render(MessageScroller::Item.new) { "b" }
      render(MessageScroller::Item.new(message_id: :m3, data: { scroll_anchor: "custom" })) { "c" }
    end)
    first, second, third = doc.css("[data-slot=message-scroller-item]")

    assert_equal %w[m1 true], [ first["data-message-id"], first["data-scroll-anchor"] ]
    assert_includes first["class"], "shrink"
    refute_includes first["class"], "shrink-0"
    assert_nil second["data-message-id"]
    assert_equal "false", second["data-scroll-anchor"]
    assert_equal %w[m3 custom], [ third["data-message-id"], third["data-scroll-anchor"] ]
  end

  test "the button renders inactive with the default content, direction and Chadcn::Button classes" do
    button = fragment(transcript).at_css(BUTTON)

    assert_equal "message-scroller-button", button["data-slot"]
    assert_equal %w[secondary icon-sm end false], [ button["data-variant"], button["data-size"], button["data-direction"], button["data-active"] ]
    assert_equal "button", button["type"]
    assert_equal "", button["inert"]
    assert_equal "-1", button["tabindex"]
    assert_equal "Scroll to end", button.text.strip
    assert_includes button.at_css("svg[aria-hidden=true]")["class"], "lucide-arrow-down"
    assert_includes button["class"], "size-8"
    refute_includes button["class"], "bg-secondary"
    refute_includes button["class"], "transition-all"
    assert_includes button["class"], "data-[direction=end]:bottom-4"
    assert_includes button["data-action"], "click->chadcn--message-scroller#press"
  end

  def custom_button
    fragment(render_view do
      render(MessageScroller::Button.new(direction: :start, variant: :outline, size: :icon_lg, behavior: :auto, type: "submit",
                                         class: "size-10 rounded-full", tab_index: 2, data: { action: "click->x#y" })) { "Up" }
    end).at_css(BUTTON)
  end

  test "button options set direction, variant, size, type and the behavior param" do
    button = custom_button

    assert_equal %w[start outline icon-lg submit], [ button["data-direction"], button["data-variant"], button["data-size"], button["type"] ]
    assert_equal "auto", button["data-chadcn--message-scroller-behavior-param"]
  end

  test "a caller click action runs before the press action" do
    assert_equal "click->x#y click->chadcn--message-scroller#press", custom_button["data-action"]
  end

  test "a caller tab_index becomes the active tabindex while the button stays out of the tab order" do
    button = custom_button

    assert_equal "2", button["data-chadcn--message-scroller-active-tabindex"]
    assert_equal "-1", button["tabindex"]
  end

  test "a caller class wins the size conflict and block content replaces the label" do
    button = custom_button

    assert_equal "Up", button.text
    assert_includes button["class"], "size-10"
    refute_includes button["class"], "size-8"
    assert_includes button["class"], "rounded-full"
  end

  test "the label defaults from the direction and the label option overrides it" do
    assert_equal "Scroll to start", fragment(render_view { render(MessageScroller::Button.new(direction: "start")) }).at_css(BUTTON).text.strip
    assert_equal "Jump", fragment(render_view { render(MessageScroller::Button.new(label: "Jump")) }).at_css(BUTTON).text.strip
  end

  test "button render: takes a tag or a component and joins the classes plainly" do
    link = fragment(render_view { render(MessageScroller::Button.new(render: :a, href: "#end")) }).at_css(BUTTON)

    assert_equal "#end", link["href"]
    assert_equal "message-scroller-button", link["data-slot"]
    assert_includes link["class"], "absolute"

    child = fragment(render_view do
      render(MessageScroller::Button.new(render: Chadcn::Button.new(variant: "ghost", class: "extra"))) { "Go" }
    end).at_css(BUTTON)

    assert_includes child["class"], "extra"
    assert_equal "message-scroller-button", child["data-slot"]
  end

  test "every spec helper renders like the explicit part" do
    helpers = render_view do
      render(MessageScroller.new(class: "h-80")) do |scroller|
        scroller.provider(auto_scroll: true) do
          scroller.viewport(class: "px-2") do
            scroller.content(class: "gap-4") { scroller.item(message_id: "m1", scroll_anchor: true) { "rows" } }
          end
          scroller.button(direction: "start")
        end
      end
    end
    explicit = render_view do
      render(MessageScroller.new(class: "h-80")) do
        render(MessageScroller::Provider.new(auto_scroll: true)) do
          render(MessageScroller::Viewport.new(class: "px-2")) do
            render(MessageScroller::Content.new(class: "gap-4")) do
              render(MessageScroller::Item.new(message_id: "m1", scroll_anchor: true)) { "rows" }
            end
          end
          render(MessageScroller::Button.new(direction: "start"))
        end
      end
    end

    assert_equal explicit, helpers
    refute_empty fragment(helpers).css("[data-slot=message-scroller-item]")
  end

  test "the button merges a caller class under every spelling" do
    [ { class: "size-10" }, { class_name: "size-10" }, { "class" => "size-10" } ].each do |spelling|
      button = fragment(render_view { render(MessageScroller::Button.new(**spelling)) }).at_css(BUTTON)

      assert_includes button["class"], "size-10", spelling.inspect
      refute_includes button["class"], "size-8", spelling.inspect
      assert_includes button["class"], "data-[direction=end]:bottom-4", spelling.inspect
    end
  end

  test "the button keeps a caller class through render:" do
    link = fragment(render_view { render(MessageScroller::Button.new(render: :a, class_name: "size-10")) }).at_css(BUTTON)

    assert_includes link["class"], "size-10"
    assert_includes link["class"], "data-[direction=end]:bottom-4"
  end

  test "auto_scroll defaults to false and the behavior param to smooth" do
    doc = fragment(transcript)

    assert_equal "false", doc.at_css(HOST)["data-chadcn--message-scroller-auto-scroll-value"]
    assert_equal "smooth", doc.at_css(BUTTON)["data-chadcn--message-scroller-behavior-param"]
  end

  test "provider data attributes merge onto the host" do
    host = fragment(transcript(provider: { data: { test_id: "chat" } })).at_css(HOST)

    assert_equal "chat", host["data-test-id"]
    assert_equal "chadcn--message-scroller", host["data-controller"]
  end

  test "an invalid button variant or behavior raises" do
    assert_raises(ArgumentError) { render_view { render(MessageScroller::Button.new(variant: "bogus")) } }
    assert_raises(ArgumentError) { MessageScroller::Button.new(behavior: "slow") }
  end

  test "a behavior is accepted as a symbol or a string" do
    %i[instant smooth].each do |behavior|
      [ behavior, behavior.to_s ].each do |value|
        button = fragment(render_view { render(MessageScroller::Button.new(behavior: value)) }).at_css(BUTTON)

        assert_equal behavior.to_s, button["data-chadcn--message-scroller-behavior-param"]
      end
    end
  end
end

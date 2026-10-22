# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::HoverCardTest < Chadcn::TestCase
  HoverCard = Chadcn::HoverCard

  def render_card(root: {}, trigger: {}, content: {}, &block)
    Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render HoverCard.new(**root) do
          render HoverCard::Trigger.new(**trigger) { plain "Hover" }
          render HoverCard::Content.new(**content), &block || proc { plain "Card" }
        end
      end
    end.new.call
  end

  test "trigger is an anchor controller host without aria" do
    out = render_card

    assert_match(/<a [^>]*data-slot="hover-card-trigger"/, out)
    assert_includes out, 'data-state="closed"'
    assert_includes out, 'data-controller="chadcn--hover-card"'
    assert_includes out, 'data-chadcn--hover-card-open-delay-value="700"'
    assert_includes out, 'data-chadcn--hover-card-close-delay-value="300"'
    assert_not_includes out, "aria-"
  end

  test "content is shipped in an inert template with the oracle classes" do
    out = render_card(content: { class: "w-80", side: :left, dir: "rtl" })

    assert_match(/<template data-chadcn--hover-card-template="hover-card-content-\d+"/, out)
    assert_includes out, 'data-slot="hover-card-content"'
    assert_includes out, "w-80"
    assert_not_includes out, "w-64"
    assert_includes out, "&quot;side&quot;:&quot;left&quot;"
    assert_includes out, "&quot;sideOffset&quot;:4"
    assert_includes out, 'dir="rtl"'
    assert_includes out, "--radix-hover-card-trigger-width: var(--radix-popper-anchor-width)"
  end

  test "open and controlled state reach the trigger" do
    out = render_card(root: { open: true, open_delay: 100 })

    assert_includes out, 'data-state="open"'
    assert_includes out, 'data-chadcn--hover-card-controlled-value="true"'
    assert_includes out, 'data-chadcn--hover-card-open-delay-value="100"'
  end

  test "as_child merges onto the child" do
    out = render_card(trigger: { as_child: :span, class: "x" })

    assert_match(/<span [^>]*data-slot="hover-card-trigger"/, out)
  end

  test "parts outside a root raise" do
    assert_match(/`HoverCardTrigger` must be used within `HoverCard`/, assert_raises(ArgumentError) { HoverCard::Trigger.new.call }.message)
    assert_match(/`HoverCardContent` must be used within `HoverCard`/, assert_raises(ArgumentError) { HoverCard::Content.new.call }.message)
  end

  test "yielded root exposes helpers that render like the explicit parts" do
    %i[trigger content].each { |helper| assert_respond_to HoverCard.new, helper }

    helpers = Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render HoverCard.new do |card|
          card.trigger { plain "Hover" }
          card.content { plain "Card" }
        end
      end
    end.new.call

    assert_equal render_card, helpers
  end

  test "content positioning keywords are serialized for the controller" do
    out = render_card(content: { side: :top, side_offset: 8, align: :start, align_offset: 2, avoid_collisions: false, collision_padding: 4,
                                 collision_boundary: "#b", arrow_padding: 3, sticky: :always, hide_when_detached: true, update_position_strategy: :always })
    options = JSON.parse(Nokogiri::HTML5.fragment(out).at_css("template[data-chadcn--hover-card-template]")["data-options"])

    assert_equal({ "side" => "top", "sideOffset" => 8, "align" => "start", "alignOffset" => 2, "avoidCollisions" => false, "collisionPadding" => 4,
                   "collisionBoundary" => "#b", "arrowPadding" => 3, "sticky" => "always", "hideWhenDetached" => true,
                   "updatePositionStrategy" => "always" }, options)
  end

  test "force_mount is accepted and has no effect" do
    out = render_card(content: { force_mount: true })
    options = JSON.parse(Nokogiri::HTML5.fragment(out).at_css("template[data-chadcn--hover-card-template]")["data-options"])

    assert_not_includes options, "forceMount"
  end

  test "open_delay and close_delay reach the trigger" do
    trigger = Nokogiri::HTML5.fragment(render_card(root: { open_delay: 10, close_delay: 20 })).at_css("a")

    assert_equal "10", trigger["data-chadcn--hover-card-open-delay-value"]
    assert_equal "20", trigger["data-chadcn--hover-card-close-delay-value"]
  end

  test "attrs merge onto the trigger" do
    trigger = Nokogiri::HTML5.fragment(render_card(trigger: { class: "x-trigger", href: "/u/1" })).at_css("a")

    assert_includes trigger["class"], "x-trigger"
    assert_equal "/u/1", trigger["href"]
  end
end

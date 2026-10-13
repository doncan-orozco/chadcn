# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::HoverCardTest < Phlex::Shadcn::TestCase
  HoverCard = Phlex::Shadcn::HoverCard

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
    assert_includes out, 'data-controller="v2--hover-card"'
    assert_includes out, 'data-v2--hover-card-open-delay-value="700"'
    assert_includes out, 'data-v2--hover-card-close-delay-value="300"'
    assert_not_includes out, "aria-"
  end

  test "content is shipped in an inert template with the oracle classes" do
    out = render_card(content: { class: "w-80", side: :left, dir: "rtl" })

    assert_match(/<template data-v2--hover-card-template="hover-card-content-\d+"/, out)
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
    assert_includes out, 'data-v2--hover-card-controlled-value="true"'
    assert_includes out, 'data-v2--hover-card-open-delay-value="100"'
  end

  test "as_child merges onto the child" do
    out = render_card(trigger: { as_child: :span, class: "x" })

    assert_match(/<span [^>]*data-slot="hover-card-trigger"/, out)
  end

  test "parts outside a root raise" do
    assert_raises(ArgumentError) { HoverCard::Trigger.new.call }
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
end

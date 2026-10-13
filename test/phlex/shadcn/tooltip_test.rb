# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::TooltipTest < Phlex::Shadcn::TestCase
  Tooltip = Phlex::Shadcn::Tooltip

  def render_tooltip(root: {}, provider: {}, trigger: {}, content: {}, &block)
    Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render Tooltip::Provider.new(**provider) do
          render Tooltip.new(**root) do
            render Tooltip::Trigger.new(**trigger) { plain "Hover" }
            render Tooltip::Content.new(**content), &block || proc { plain "Tip" }
          end
        end
      end
    end.new.call
  end

  test "trigger is a button controller host without type" do
    out = render_tooltip

    assert_includes out, 'data-slot="tooltip-trigger"'
    assert_includes out, 'data-state="closed"'
    assert_includes out, 'data-controller="shadcn--tooltip"'
    assert_not_includes out, "type="
    assert_not_includes out, 'data-slot="tooltip-provider"'
  end

  test "content is shipped in an inert template with the oracle classes and arrow" do
    out = render_tooltip(content: { class: "max-w-48" })

    assert_match(/<template data-shadcn--tooltip-template="tooltip-content-\d+"/, out)
    assert_includes out, 'data-slot="tooltip-content"'
    assert_includes out, 'role="tooltip"'
    assert_includes out, "max-w-48"
    assert_includes out, "<polygon"
  end

  test "aria-label switches to a visually hidden tooltip" do
    out = render_tooltip(content: { aria: { label: "Shortcut" } })

    assert_not_includes out, "aria-label"
    assert_includes out, ">Shortcut</span>"
  end

  test "open renders instant-open and aria-describedby merged with the caller ids" do
    out = render_tooltip(root: { default_open: true }, trigger: { aria: { describedby: "extra" } })

    assert_includes out, 'data-state="instant-open"'
    assert_match(/aria-describedby="extra tooltip-content-\d+"/, out)
  end

  test "delay falls back to the provider and the root wins" do
    assert_includes render_tooltip(provider: { delay_duration: 700 }), 'data-shadcn--tooltip-delay-duration-value="700"'
    assert_includes render_tooltip(provider: { delay_duration: 700 }, root: { delay_duration: 500 }),
                    'data-shadcn--tooltip-delay-duration-value="500"'
  end

  test "options reach the template and as_child merges onto the child" do
    out = render_tooltip(content: { side: :left, align_offset: 12 }, trigger: { as_child: :a, href: "#x" })

    assert_includes out, "&quot;side&quot;:&quot;left&quot;"
    assert_includes out, "&quot;alignOffset&quot;:12"
    assert_match(/<a [^>]*data-slot="tooltip-trigger"/, out)
  end

  test "root outside a provider raises" do
    assert_raises(ArgumentError) { Tooltip.new.call { |_| nil } }
  end

  test "yielded root exposes helpers that render like the explicit parts" do
    %i[trigger content provider].each { |helper| assert_respond_to Tooltip.new, helper }

    explicit = render_tooltip
    helpers = Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render Tooltip::Provider.new do
          render Tooltip.new do |tooltip|
            tooltip.trigger { plain "Hover" }
            tooltip.content { plain "Tip" }
          end
        end
      end
    end.new.call

    assert_equal explicit, helpers
  end
end

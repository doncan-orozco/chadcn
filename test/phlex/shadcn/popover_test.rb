# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::PopoverTest < Phlex::Shadcn::TestCase
  Popover = Phlex::Shadcn::Popover

  def render_popover(root: {}, trigger: {}, content: {}, &block)
    Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render Popover.new(**root) do
          render Popover::Trigger.new(**trigger) { plain "Open" }
          render Popover::Content.new(**content), &block || proc { plain "Body" }
        end
      end
    end.new.call
  end

  test "closed trigger hosts the controller and content ships in a template" do
    out = render_popover

    assert_includes out, 'data-slot="popover-trigger"'
    assert_includes out, 'aria-haspopup="dialog"'
    assert_includes out, 'aria-expanded="false"'
    assert_includes out, 'data-controller="v2--popover"'
    assert_match(/<template data-v2--popover-template="popover-\d+"/, out)
    assert_includes out, 'data-slot="popover-content"'
    assert_includes out, 'role="dialog"'
  end

  test "default_open renders aria-controls and open state" do
    out = render_popover(root: { default_open: true })

    assert_includes out, 'aria-expanded="true"'
    assert_match(/aria-controls="popover-\d+-content"/, out)
  end

  # Radix spreads contentProps after the generated id (the trigger's aria-controls keeps the generated one).
  test "a caller id replaces the generated content id but not the trigger's aria-controls" do
    out = render_popover(root: { default_open: true }, content: { id: "mine" })

    assert_includes out, '<div id="mine"'
    assert_match(/aria-controls="popover-\d+-content"/, out)
    refute_match(/id="popover-\d+-content"/, out)
  end

  test "merges class and passes attrs through" do
    out = render_popover(trigger: { data: { foo: "bar" } }, content: { class: "w-80", side: :top })

    assert_includes out, 'data-foo="bar"'
    assert_includes out, "w-80"
    assert_includes out, "&quot;side&quot;:&quot;top&quot;"
  end

  test "every DX helper renders the same HTML as the explicit call" do
    root = Popover.new

    %i[trigger content anchor header title description].each { |name| assert_respond_to root, name }

    helper = Class.new(Phlex::HTML) do
      def view_template
        render Popover.new do |popover|
          popover.header { popover.title { "T" } }
          popover.description { "D" }
        end
      end
    end.new.call
    explicit = Class.new(Phlex::HTML) do
      def view_template
        render Popover.new do
          render(Popover::Header.new { render(Popover::Title.new { "T" }) })
          render(Popover::Description.new { "D" })
        end
      end
    end.new.call

    assert_equal explicit, helper
  end
end

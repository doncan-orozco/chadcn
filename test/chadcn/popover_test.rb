# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::PopoverTest < Chadcn::TestCase
  Popover = Chadcn::Popover

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
    assert_includes out, 'data-controller="shadcn--popover"'
    assert_match(/<template data-shadcn--popover-template="popover-\d+"/, out)
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

  test "content positioning keywords are serialized for the controller" do
    out = render_popover(content: { side: :top, side_offset: 8, align: :start, align_offset: 2, avoid_collisions: false, collision_padding: 4,
                                    collision_boundary: "#b", arrow_padding: 3, sticky: :always, hide_when_detached: true, update_position_strategy: :always })
    options = JSON.parse(Nokogiri::HTML5.fragment(out).at_css("template[data-shadcn--popover-template]")["data-options"])

    assert_equal({ "side" => "top", "sideOffset" => 8, "align" => "start", "alignOffset" => 2, "avoidCollisions" => false, "collisionPadding" => 4,
                   "collisionBoundary" => "#b", "arrowPadding" => 3, "sticky" => "always", "hideWhenDetached" => true,
                   "updatePositionStrategy" => "always" }, options)
  end

  test "force_mount is accepted and has no effect" do
    out = render_popover(content: { force_mount: true })
    options = JSON.parse(Nokogiri::HTML5.fragment(out).at_css("template[data-shadcn--popover-template]")["data-options"])

    assert_not_includes options, "forceMount"
  end

  test "modal reaches the controller host" do
    html = Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render Popover.new(modal: true) do
          render(Popover::Trigger.new) { "T" }
          render(Popover::Content.new) { "C" }
        end
      end
    end.new.call

    assert_equal "true", Nokogiri::HTML5.fragment(html).at_css("[data-controller=shadcn--popover]")["data-shadcn--popover-modal-value"]
  end

  test "anchor and header parts merge their class" do
    html = Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render Popover.new do
          render(Popover::Anchor.new(class: "x-anchor")) { "A" }
          render(Popover::Trigger.new) { "T" }
          render(Popover::Content.new) { render(Popover::Header.new(class: "x-header")) { "H" } }
        end
      end
    end.new.call
    doc = Nokogiri::HTML5.fragment(html)

    assert_includes doc.at_css("[data-slot=popover-anchor]")["class"], "x-anchor"
    assert_includes doc.at_css("[data-slot=popover-header]")["class"], "x-header"
  end

  test "parts that need the root raise a clear ArgumentError outside it" do
    %i[Trigger Anchor Content].each do |part|
      error = assert_raises(ArgumentError, part.to_s) { Popover.const_get(part).new.call }

      assert_match(/must be used within Popover/, error.message, part.to_s)
    end
  end

  test "as_child renders the trigger onto the given element" do
    out = render_popover(trigger: { as_child: :a, href: "/x", class: "t" })

    assert_match(/<a [^>]*data-slot="popover-trigger"/, out)
    assert_includes out, 'href="/x"'
  end
end

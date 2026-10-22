# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::AttachmentTest < Chadcn::TestCase
  PARTS = { group: "attachment-group", media: "attachment-media", content: "attachment-content",
            title: "attachment-title", description: "attachment-description", actions: "attachment-actions",
            action: "attachment-action", trigger: "attachment-trigger" }.freeze

  def html(**, &block)
    Chadcn::Attachment.new(**).call(&block || proc { |_| "Body" })
  end

  test "root renders data attributes, defaults and merged class" do
    out = html(class: "w-full", id: "a")

    assert_includes out, 'data-slot="attachment"'
    assert_includes out, 'data-state="done" data-size="default" data-orientation="horizontal"'
    assert_includes out, 'id="a"'
    assert_not_includes out, "w-fit"
  end

  test "accepts symbols and rejects unknown options" do
    assert_includes html(state: :error, size: :xs, orientation: :vertical), 'data-state="error"'
    assert_raises(ArgumentError) { html(size: "huge") }
  end

  test "every part renders its slot" do
    PARTS.each do |name, slot|
      assert_includes html { |a| a.public_send(name) { "x" } }, %(data-slot="#{slot}")
    end
  end

  test "action is a ghost icon-xs button and trigger defaults to type button" do
    out = html { |a| a.action { "x" } }

    assert_includes out, 'data-variant="ghost"'
    assert_includes out, 'data-size="icon-xs"'
    assert_includes html(&:trigger), 'type="button"'
  end

  test "trigger as_child drops type and joins classes" do
    out = html { |a| a.trigger(as_child: :a, type: "submit", href: "/x", class: "z-0") { "go" } }

    assert_includes out, "<a "
    assert_not_includes out, "type="
  end

  test "helpers render the same HTML as the explicit classes" do
    helpers = html { |a| PARTS.each_key { |n| a.public_send(n, class: "k") { "x" } } }
    explicit = html do |a|
      PARTS.each_key { |n| a.render Chadcn::Attachment.const_get(n.to_s.capitalize).new(class: "k") { "x" } }
    end

    assert_equal explicit, helpers
  end

  test "media rejects an unknown variant and accepts the image one" do
    assert_raises(ArgumentError) { Chadcn::Attachment::Media.new(variant: :nope) }
    assert_includes Chadcn::Attachment::Media.new(variant: :image).call { "x" }, 'data-variant="image"'
  end
end

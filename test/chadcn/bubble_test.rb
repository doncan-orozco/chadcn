# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::BubbleTest < Chadcn::TestCase
  def html(**, &block)
    Chadcn::Bubble.new(**).call(&block || proc { |_| "Hi" })
  end

  test "renders each variant with slot, data attrs and defaults" do
    Chadcn::Bubble::VARIANTS.each_key do |v|
      out = html(variant: v)

      assert_includes out, 'data-slot="bubble"'
      assert_includes out, %(data-variant="#{v}")
    end
    assert_includes html, 'data-align="start"'
    assert_includes html(variant: :tinted, align: :end), 'data-align="end"'
  end

  test "class merges last, attrs pass through and data attrs are overridable" do
    out = html(class: "max-w-full", id: "b", data: { align: "end" })

    assert_not_includes out, "max-w-[80%]"
    assert_includes out, 'id="b"'
    assert_includes out, 'data-align="end"'
  end

  test "unknown options raise" do
    assert_raises(ArgumentError) { html(variant: :nope) }
    assert_raises(ArgumentError) { html(align: :middle) }
  end

  test "reactions side and align" do
    out = html { |b| b.reactions(side: :top, align: :start) { "x" } }

    assert_includes out, "top-0 -translate-y-3/4 left-3"
    assert_includes out, 'data-align="start" data-side="top"'
  end

  test "content as_child" do
    out = html { |b| b.content(as_child: :button, type: "button") { "x" } }

    assert_match(/<button[^>]*data-slot="bubble-content"/, out)
  end

  test "helpers render the same HTML as the explicit classes" do
    helpers = html do |b|
      b.group { "g" }
      b.content(class: "c") { "C" }
      b.reactions { "R" }
    end
    explicit = html do |b|
      b.render(Chadcn::Bubble::Group.new { "g" })
      b.render Chadcn::Bubble::Content.new(class: "c") { "C" }
      b.render(Chadcn::Bubble::Reactions.new { "R" })
    end

    assert_equal explicit, helpers
  end

  test "reactions reject an unknown side or align" do
    assert_raises(ArgumentError) { Chadcn::Bubble::Reactions.new(side: :left) }
    assert_raises(ArgumentError) { Chadcn::Bubble::Reactions.new(align: :middle) }
  end
end

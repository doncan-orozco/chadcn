# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::MarkerTest < Phlex::Shadcn::TestCase
  def html(**opts)
    Phlex::Shadcn::Marker.new(**opts).call do |m|
      m.icon { "i" }
      m.content { "Text" }
    end
  end

  test "renders defaults" do
    out = html

    assert_includes out, "<div"
    assert_includes out, 'data-slot="marker"'
    assert_includes out, 'data-variant="default"'
    assert_includes out, 'data-slot="marker-icon"'
    assert_includes out, 'aria-hidden="true"'
    assert_includes out, 'data-slot="marker-content"'
  end

  test "renders every variant" do
    Phlex::Shadcn::Marker::VARIANTS.each_key { |v| assert_includes html(variant: v.to_sym), %(data-variant="#{v}") }
    assert_includes html(variant: :separator), "before:bg-border"
    assert_includes html(variant: :border), "border-b"
  end

  test "class merged last and attrs pass through" do
    out = html(class: "gap-4", id: "x", role: "status")

    assert_includes out, "gap-4"
    assert_not_includes out, "gap-2"
    assert_includes out, 'id="x"'
    assert_includes out, 'role="status"'
  end

  test "unknown variant raises" do
    assert_raises(ArgumentError) { html(variant: :nope) }
  end

  test "as_child tag" do
    out = html(as_child: :a, href: "/x")

    assert_includes out, "<a"
    assert_includes out, 'data-slot="marker"'
  end

  test "variants helper" do
    assert_includes Phlex::Shadcn::Marker.variants(variant: :border, class: "pb-4"), "border-b"
    assert_not_includes Phlex::Shadcn::Marker.variants(class: "gap-4"), "gap-2"
  end

  test "helpers match explicit parts" do
    helper = Phlex::Shadcn::Marker.new.call do |m|
      m.icon(class: "a") { "x" }
      m.content(id: "c") { "y" }
    end
    explicit = Phlex::Shadcn::Marker.new.call do |m|
      m.render Phlex::Shadcn::Marker::Icon.new(class: "a") { "x" }
      m.render Phlex::Shadcn::Marker::Content.new(id: "c") { "y" }
    end

    assert_equal explicit, helper
  end
end

# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::BadgeTest < Phlex::Shadcn::TestCase
  def html(**opts)
    Phlex::Shadcn::Badge.new(**opts).call { |_| "New" }
  end

  test "renders defaults" do
    out = html

    assert_includes out, "<span"
    assert_includes out, 'data-slot="badge"'
    assert_includes out, 'data-variant="default"'
    assert_includes out, "bg-primary"
  end

  test "renders every variant" do
    Phlex::Shadcn::Badge::VARIANTS.each_key { |v| assert_includes html(variant: v.to_sym), %(data-variant="#{v}") }
  end

  test "class is merged last and attrs pass through" do
    out = html(class: "rounded-md", id: "x", data: { foo: "1" })

    assert_includes out, "rounded-md"
    assert_not_includes out, "rounded-full"
    assert_includes out, 'id="x"'
    assert_includes out, 'data-foo="1"'
  end

  test "unknown variant raises" do
    assert_raises(ArgumentError) { html(variant: :nope) }
  end

  test "as_child tag" do
    out = html(as_child: :a, href: "/x")

    assert_includes out, "<a"
    assert_includes out, 'href="/x"'
    assert_includes out, 'data-slot="badge"'
  end

  test "variants helper" do
    assert_includes Phlex::Shadcn::Badge.variants(variant: :outline, class: "px-1"), "border-border"
    assert_not_includes Phlex::Shadcn::Badge.variants(class: "px-1"), "px-2"
  end
end

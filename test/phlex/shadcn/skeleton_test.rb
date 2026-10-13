# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::SkeletonTest < Phlex::Shadcn::TestCase
  def html(**, &)
    Phlex::Shadcn::Skeleton.new(**).call(&)
  end

  test "renders defaults" do
    out = html

    assert_includes out, "<div"
    assert_includes out, 'data-slot="skeleton"'
    assert_includes out, "animate-pulse rounded-md bg-accent"
  end

  test "class is merged last and attrs pass through" do
    out = html(class: "rounded-full h-12 w-12", id: "x", data: { foo: "1" })

    assert_includes out, "rounded-full"
    assert_not_includes out, "rounded-md"
    assert_includes out, 'id="x"'
    assert_includes out, 'data-foo="1"'
  end

  test "caller data-slot wins" do
    assert_includes html(data: { slot: "custom" }), 'data-slot="custom"'
  end
end

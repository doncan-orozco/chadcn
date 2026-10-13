# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::BreadcrumbTest < Phlex::Shadcn::TestCase
  B = Phlex::Shadcn::Breadcrumb

  def render_root(**, &)
    B.new(**).call(&)
  end

  test "root has aria-label, slot, and class is not merged" do
    out = render_root(class: "p-2 p-4 border") { |_| "x" }

    assert_includes out, 'aria-label="breadcrumb"'
    assert_includes out, 'data-slot="breadcrumb"'
    assert_includes out, 'class="p-2 p-4 border"'
    assert_not_includes render_root { |_| "x" }, "class="
  end

  test "parts render slots and merge class" do
    assert_includes B::List.new(class: "gap-0").call { "x" }, "gap-0"
    assert_includes B::Item.new.call { "x" }, 'data-slot="breadcrumb-item"'
    assert_includes B::Page.new.call { "x" }, 'aria-current="page"'
    assert_includes B::Page.new(aria: { current: "location" }).call { "x" }, 'aria-current="location"'
    link = B::Link.new(href: "/a").call { "x" }

    assert_includes link, "<a"
    assert_includes link, 'href="/a"'
  end

  test "link as_child renders the given tag" do
    assert_includes B::Link.new(as_child: :span).call { "x" }, "<span"
  end

  test "separator defaults to chevron and ellipsis ignores blocks" do
    assert_includes B::Separator.new.call, "lucide-chevron-right"
    out = B::Separator.new.call { "/" }

    assert_not_includes out, "<svg"
    assert_includes B::Ellipsis.new.call { "ignored" }, "More"
    assert_not_includes B::Ellipsis.new.call { "ignored" }, "ignored"
  end

  test "dx helpers exist and match explicit rendering" do
    { list: B::List, item: B::Item, link: B::Link, page: B::Page, separator: B::Separator, ellipsis: B::Ellipsis }.each do |name, klass|
      root = B.new

      assert_respond_to root, name
      helper_html = Class.new(Phlex::HTML) do
        define_method(:view_template) { render(B.new { |b| b.public_send(name, id: "i") { "x" } }) }
      end.new.call
      explicit = Class.new(Phlex::HTML) do
        define_method(:view_template) { render(B.new { render klass.new(id: "i") { "x" } }) }
      end.new.call

      assert_equal explicit, helper_html
    end
  end
end

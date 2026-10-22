# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::BreadcrumbTest < Chadcn::TestCase
  Breadcrumb = Chadcn::Breadcrumb

  def render_root(**, &)
    Breadcrumb.new(**).call(&)
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  test "root has aria-label, slot, and class is not merged" do
    nav = fragment(render_root(class: "p-2 p-4 border") { |_| "x" }).at_css("nav")

    assert_equal "breadcrumb", nav["aria-label"]
    assert_equal "breadcrumb", nav["data-slot"]
    assert_equal "p-2 p-4 border", nav["class"]
    assert_not fragment(render_root { |_| "x" }).at_css("nav").key?("class")
  end

  test "parts render slots and merge class" do
    assert_includes fragment(Breadcrumb::List.new(class: "gap-0").call { "x" }).at_css("ol[data-slot=breadcrumb-list]")["class"].split, "gap-0"
    assert fragment(Breadcrumb::Item.new.call { "x" }).at_css("li[data-slot=breadcrumb-item]")
    assert_equal "page", fragment(Breadcrumb::Page.new.call { "x" }).at_css("[data-slot=breadcrumb-page]")["aria-current"]
    assert_equal "location",
                 fragment(Breadcrumb::Page.new(aria: { current: "location" }).call { "x" }).at_css("[data-slot=breadcrumb-page]")["aria-current"]
    link = fragment(Breadcrumb::Link.new(href: "/a").call { "x" }).at_css("a[data-slot=breadcrumb-link]")

    assert_equal "/a", link["href"]
  end

  test "link as_child renders the given tag" do
    assert fragment(Breadcrumb::Link.new(as_child: :span).call { "x" }).at_css("span[data-slot=breadcrumb-link]")
  end

  test "separator defaults to chevron, takes custom content and keeps its attributes" do
    default = fragment(Breadcrumb::Separator.new.call).at_css("[data-slot=breadcrumb-separator]")
    custom = fragment(Breadcrumb::Separator.new(class: "mx-1").call { "/" }).at_css("[data-slot=breadcrumb-separator]")

    assert default.at_css("svg.lucide-chevron-right")
    assert_equal "/", custom.text
    assert_nil custom.at_css("svg")
    assert_includes custom["class"].split, "mx-1"
    assert_equal "presentation", custom["role"]
  end

  test "ellipsis ignores blocks and takes a custom label" do
    ignored = fragment(Breadcrumb::Ellipsis.new.call { "ignored" }).at_css("[data-slot=breadcrumb-ellipsis]")
    labelled = fragment(Breadcrumb::Ellipsis.new(label: "Hidden").call).at_css("[data-slot=breadcrumb-ellipsis]")

    assert_equal "More", ignored.at_css(".sr-only").text
    assert_not_includes ignored.text, "ignored"
    assert_equal "Hidden", labelled.at_css(".sr-only").text
  end

  test "dx helpers exist and match explicit rendering" do
    { list: Breadcrumb::List, item: Breadcrumb::Item, link: Breadcrumb::Link, page: Breadcrumb::Page,
      separator: Breadcrumb::Separator, ellipsis: Breadcrumb::Ellipsis }.each do |name, klass|
      assert_respond_to Breadcrumb.new, name
      helper_html = Class.new(Phlex::HTML) do
        define_method(:view_template) { render(Breadcrumb.new { |breadcrumb| breadcrumb.public_send(name, id: "i") { "x" } }) }
      end.new.call
      explicit = Class.new(Phlex::HTML) do
        define_method(:view_template) { render(Breadcrumb.new { render klass.new(id: "i") { "x" } }) }
      end.new.call

      assert_equal explicit, helper_html
    end
  end
end

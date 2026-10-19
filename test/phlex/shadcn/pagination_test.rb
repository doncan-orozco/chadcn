# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::PaginationTest < Phlex::Shadcn::TestCase
  Pagination = Phlex::Shadcn::Pagination

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  test "root renders nav with slot and merged class" do
    nav = fragment(Pagination.new(class: "mt-4").call { |_| "x" }).at_css("nav")

    assert_equal "pagination", nav["data-slot"]
    assert_equal "pagination", nav["aria-label"]
    assert_equal "navigation", nav["role"]
    assert_includes nav["class"].split, "mt-4"
    assert_includes nav["class"].split, "mx-auto"
  end

  test "link active state is tri-state" do
    nil_link = fragment(Pagination::Link.new(href: "#").call { "1" }).at_css("a")
    inactive = fragment(Pagination::Link.new(is_active: false).call { "1" }).at_css("a")
    active = fragment(Pagination::Link.new(is_active: true, href: "#").call { "2" }).at_css("a")

    assert_equal "pagination-link", active["data-slot"]
    assert_not nil_link.key?("data-active")
    assert_equal "false", inactive["data-active"]
    assert_not inactive.key?("aria-current")
    assert_equal "true", active["data-active"]
    assert_equal "page", active["aria-current"]
  end

  test "link size picks the button variant" do
    icon = fragment(Pagination::Link.new(href: "#").call { "x" }).at_css("a")
    sized = fragment(Pagination::Link.new(size: "default", href: "#").call { "x" }).at_css("a")

    assert_includes icon["class"].split, "size-9"
    assert_includes sized["class"].split, "px-4"
  end

  test "item class is emitted verbatim" do
    assert_equal "p-2 p-4", fragment(Pagination::Item.new(class: "p-2 p-4").call { "x" }).at_css("li")["class"]
  end

  test "previous and next label themselves and take a size" do
    previous = fragment(Pagination::Previous.new(href: "#").call).at_css("a")
    large = fragment(Pagination::Previous.new(href: "#", size: :lg).call).at_css("a")
    following = fragment(Pagination::Next.new(href: "#").call).at_css("a")

    assert_equal "Go to previous page", previous["aria-label"]
    assert_equal "Previous", previous.at_css("span").text
    assert_equal "Go to next page", following["aria-label"]
    assert_equal "Next", following.at_css("span").text
    assert_includes previous["class"].split, "h-9"
    assert_includes large["class"].split, "h-10"
    assert_not_includes large["class"].split, "h-9"
  end

  test "previous, next and ellipsis strings can be overridden" do
    previous = fragment(Pagination::Previous.new(href: "#", label: "Anterior", aria_label: "Ir a la página anterior").call).at_css("a")
    following = fragment(Pagination::Next.new(href: "#", label: "Siguiente", aria_label: "Ir a la página siguiente").call).at_css("a")
    ellipsis = fragment(Pagination::Ellipsis.new(label: "Más páginas").call)

    assert_equal "Ir a la página anterior", previous["aria-label"]
    assert_equal "Anterior", previous.at_css("span").text
    assert_equal "Ir a la página siguiente", following["aria-label"]
    assert_equal "Siguiente", following.at_css("span").text
    assert_equal "Más páginas", ellipsis.at_css(".sr-only").text
  end

  test "ellipsis is hidden from assistive technology and labelled" do
    ellipsis = fragment(Pagination::Ellipsis.new.call).at_css("[data-slot=pagination-ellipsis]")

    assert_equal "true", ellipsis["aria-hidden"]
    assert_equal "More pages", ellipsis.at_css(".sr-only").text
  end

  test "helpers render the same HTML as the explicit classes" do
    helper = Pagination.new.call do |pagination|
      pagination.content { pagination.item { pagination.previous(href: "#") } }
    end
    explicit = Pagination.new.call do |pagination|
      pagination.render(Pagination::Content.new) do
        pagination.render(Pagination::Item.new) { pagination.render Pagination::Previous.new(href: "#") }
      end
    end

    assert_equal explicit, helper
  end

  test "every helper renders the same HTML as the explicit part" do
    { link: Pagination::Link, next: Pagination::Next, ellipsis: Pagination::Ellipsis, item: Pagination::Item,
      content: Pagination::Content }.each do |name, klass|
      helper = Pagination.new.call { |pagination| pagination.public_send(name, class: "z") { "x" } }
      explicit = Pagination.new.call { |pagination| pagination.render(klass.new(class: "z")) { "x" } }

      assert_equal explicit, helper, name.to_s
    end
  end
end

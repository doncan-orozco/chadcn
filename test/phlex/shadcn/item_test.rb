# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::ItemTest < Phlex::Shadcn::TestCase
  Item = Phlex::Shadcn::Item

  def html(component = Item.new, &block)
    component.call(&block || proc { |_| "x" })
  end

  test "renders defaults" do
    out = html

    assert_includes out, 'data-slot="item"'
    assert_includes out, 'data-variant="default"'
    assert_includes out, 'data-size="default"'
    assert_includes out, "gap-4 p-4"
  end

  test "renders every variant and size, strings and symbols" do
    Item::VARIANTS.each_key { |v| assert_includes html(Item.new(variant: v.to_sym)), %(data-variant="#{v}") }
    Item::SIZES.each_key { |s| assert_includes html(Item.new(size: s)), %(data-size="#{s}") }
    assert_includes html(Item.new(variant: :outline)), "border-border"
    assert_not_includes html(Item.new(variant: :outline)), "border-transparent"
  end

  test "media variants" do
    Item::Media::VARIANTS.each_key { |v| assert_includes html(Item::Media.new(variant: v.to_sym)), %(data-variant="#{v}") }
    assert_includes html(Item::Media.new), 'data-slot="item-media"'
  end

  test "class merges last and attrs pass through" do
    out = html(Item.new(class: "p-2", id: "a", data: { foo: "1" }))

    assert_includes out, "p-2"
    assert_not_includes out, " p-4"
    assert_includes out, 'id="a"'
    assert_includes out, 'data-foo="1"'
    assert_includes out, 'data-slot="item"'
  end

  test "as_child joins classes plainly" do
    out = html(Item.new(as_child: :a, href: "/x"))

    assert_includes out, "<a"
    assert_includes out, 'href="/x"'
    assert_includes out, 'data-slot="item"'
  end

  test "parts render their slot and tag" do
    { Content: "item-content", Actions: "item-actions", Group: "item-group", Title: "item-title",
      Description: "item-description", Header: "item-header", Footer: "item-footer" }.each do |name, slot|
      assert_includes html(Item.const_get(name).new), %(data-slot="#{slot}")
    end
    assert_includes html(Item::Description.new), "<p"
    assert_includes html(Item::Group.new), 'role="list"'
    assert_includes html(Item::Group.new(role: "menu")), 'role="menu"'
  end

  test "separator forwards to Separator" do
    out = Item::Separator.new(class: "my-2").call

    assert_includes out, 'data-slot="item-separator"'
    assert_includes out, 'data-orientation="horizontal"'
    assert_includes out, "my-2"
    assert_not_includes out, "my-0"
  end

  test "variants helpers" do
    assert_includes Item.variants(variant: :muted, size: :sm, class: "p-1"), "bg-muted/50"
    assert_not_includes Item.variants(class: "p-1"), " p-4"
    assert_includes Item::Media.variants(variant: :icon), "size-8"
  end

  test "every DX helper renders the same HTML as the explicit class" do
    parts = %i[media content actions group title description header footer separator]
    helpers = Item.new.call { |item| parts.each { |n| item.public_send(n, class: "k") } }
    explicit = Item.new.call do |item|
      parts.each { |n| item.render Item.const_get(n.to_s.capitalize).new(class: "k") }
    end

    assert_equal explicit, helpers
  end
end

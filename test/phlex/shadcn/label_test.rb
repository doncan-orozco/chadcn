# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::LabelTest < Phlex::Shadcn::TestCase
  def html(**, &block)
    Phlex::Shadcn::Label.new(**).call(&block || proc { |_| "Name" })
  end

  test "renders slot, base classes, controller and action" do
    out = html

    assert_includes out, "<label"
    assert_includes out, 'data-slot="label"'
    assert_includes out, "peer-disabled:opacity-50"
    assert_includes out, 'data-controller="shadcn--label"'
    assert_includes out, 'data-action="mousedown->shadcn--label#mousedown"'
  end

  test "html_for renders for and wins over for:" do
    assert_includes html(html_for: "a"), 'for="a"'
    out = html(html_for: "a", for: "b")

    assert_includes out, 'for="a"'
    assert_not_includes out, 'for="b"'
  end

  test "class merges last, attrs pass through, caller action comes first" do
    out = html(class: "text-lg", id: "x", data: { action: "mousedown->foo#bar", controller: "foo" })

    assert_includes out, "text-lg"
    assert_not_includes out, "text-sm"
    assert_includes out, 'id="x"'
    assert_includes out, 'data-action="mousedown->foo#bar mousedown->shadcn--label#mousedown"'
    assert_includes out, 'data-controller="foo shadcn--label"'
  end

  test "as_child renders the child element" do
    out = html(as_child: :span, html_for: "a")

    assert_includes out, "<span"
    assert_not_includes out, "<label"
    assert_includes out, 'data-slot="label"'
    assert_includes out, 'for="a"'
  end

  test "for: string key is replaced by html_for" do
    out = html(html_for: "a", "for" => "b")

    assert_includes out, 'for="a"'
    assert_not_includes out, 'for="b"'
  end

  test "for: passes through without html_for" do
    assert_includes html(for: "b"), 'for="b"'
  end
end

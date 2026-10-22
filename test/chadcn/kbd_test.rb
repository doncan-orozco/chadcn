# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::KbdTest < Chadcn::TestCase
  def html(**, &block)
    Chadcn::Kbd.new(**).call(&block || proc { |_| "K" })
  end

  test "renders kbd with slot, merged class and passthrough attrs" do
    out = html(class: "rounded-md", id: "k", data: { x: "1" })

    assert_includes out, "<kbd"
    assert_includes out, 'data-slot="kbd"'
    assert_includes out, "rounded-md"
    assert_not_includes out, "rounded-sm"
    assert_includes out, 'id="k"'
    assert_includes out, 'data-x="1"'
  end

  test "group helper renders the same HTML as the explicit class" do
    helper = html { |k| k.group(class: "k") { "x" } }
    explicit = html { |k| k.render Chadcn::Kbd::Group.new(class: "k") { "x" } }

    assert_equal explicit, helper
    assert_includes helper, 'data-slot="kbd-group"'
  end
end

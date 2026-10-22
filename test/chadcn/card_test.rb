# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::CardTest < Chadcn::TestCase
  PARTS = { header: "card-header", footer: "card-footer", title: "card-title",
            action: "card-action", description: "card-description", content: "card-content" }.freeze

  def html(**, &block)
    Chadcn::Card.new(**).call(&block || proc { |_| "Body" })
  end

  test "root renders slot, merged class and passthrough attrs" do
    out = html(class: "py-0", id: "c", data: { x: "1" })

    assert_includes out, 'data-slot="card"'
    assert_includes out, "py-0"
    assert_not_includes out, "py-6"
    assert_includes out, 'id="c"'
    assert_includes out, 'data-x="1"'
  end

  test "every part renders its slot" do
    PARTS.each do |name, slot|
      out = html { |c| c.public_send(name) { "x" } }

      assert_includes out, %(data-slot="#{slot}")
    end
  end

  test "helpers render the same HTML as the explicit classes" do
    helpers = html { |c| PARTS.each_key { |n| c.public_send(n, class: "k") { "x" } } }
    explicit = html do |c|
      PARTS.each_key { |n| c.render Chadcn::Card.const_get(n.to_s.capitalize).new(class: "k") { "x" } }
    end

    assert_equal explicit, helpers
  end
end

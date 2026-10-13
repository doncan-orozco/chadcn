# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::TableTest < Phlex::Shadcn::TestCase
  PARTS = { header: "table-header", body: "table-body", footer: "table-footer", row: "table-row",
            head: "table-head", cell: "table-cell", caption: "table-caption" }.freeze

  def html(**, &block)
    Phlex::Shadcn::Table.new(**).call(&block || proc { |_| "x" })
  end

  test "attrs and class go to the inner table, container is fixed" do
    out = html(class: "text-lg", id: "t")

    assert_includes out, 'data-slot="table-container"'
    assert_match(/<table[^>]*id="t"/, out)
    assert_includes out, "text-lg"
    assert_not_includes out, "text-sm"
  end

  test "every part renders its slot" do
    PARTS.each do |name, slot|
      assert_includes html { |t| t.public_send(name) { "x" } }, %(data-slot="#{slot}")
    end
  end

  test "helpers render the same HTML as the explicit classes" do
    helpers = html { |t| PARTS.each_key { |n| t.public_send(n, class: "k") { "x" } } }
    explicit = html do |t|
      PARTS.each_key { |n| t.render Phlex::Shadcn::Table.const_get(n.to_s.capitalize).new(class: "k") { "x" } }
    end

    assert_equal explicit, helpers
  end
end

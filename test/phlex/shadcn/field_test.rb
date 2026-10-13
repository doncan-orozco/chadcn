# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::FieldTest < Phlex::Shadcn::TestCase
  HELPERS = { label: "field-label", description: "field-description", group: "field-group", legend: "field-legend",
              separator: "field-separator", set: "field-set", content: "field-content", title: "field-label" }.freeze

  def html(**, &block)
    Phlex::Shadcn::Field.new(**).call(&block || proc { |_| "Body" })
  end

  test "root renders slot, role, orientation, merged class and passthrough attrs" do
    out = html(orientation: :horizontal, class: "gap-1", id: "f", data: { invalid: true })

    assert_includes out, 'data-slot="field"'
    assert_includes out, 'role="group"'
    assert_includes out, 'data-orientation="horizontal"'
    assert_includes out, "gap-1"
    assert_not_includes out, "gap-3"
    assert_includes out, 'id="f"'
    assert_includes out, 'data-invalid="true"'
  end

  test "variants matches the root class" do
    assert_includes Phlex::Shadcn::Field.variants(orientation: "responsive"), "@md/field-group:flex-row"
  end

  test "every helper renders the same HTML as the explicit class" do
    helpers = html { |f| HELPERS.each_key { |n| f.public_send(n, class: "k") { "x" } } }
    explicit = html do |f|
      HELPERS.each_key { |n| f.render Phlex::Shadcn::Field.const_get(n.to_s.capitalize).new(class: "k") { "x" } }
    end

    assert_equal explicit, helpers
    HELPERS.each_value { |slot| assert_includes helpers, %(data-slot="#{slot}") }
  end

  test "error helper renders the same HTML as the explicit class" do
    helpers = html { |f| f.error(errors: [ { "message" => "a" } ]) }
    explicit = html { |f| f.render Phlex::Shadcn::Field::Error.new(errors: [ { "message" => "a" } ]) }

    assert_equal explicit, helpers
  end

  test "error content algorithm" do
    one = html { |f| f.error(errors: [ { message: "a" }, { "message" => "a" } ]) }
    many = html { |f| f.error(errors: [ { message: "a" }, nil, { message: "b" } ]) }
    none = html { |f| f.error(errors: [ nil ]) }

    assert_includes one, ">a</div>"
    assert_not_includes one, "<ul"
    assert_equal 2, many.scan("<li>").size
    assert_not_includes none, "field-error"
  end

  test "separator marks content" do
    assert_includes html { |f| f.separator { "Or" } }, 'data-content="true"'
    assert_includes html(&:separator), 'data-content="false"'
  end
end

# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::FieldTest < Chadcn::TestCase
  HELPERS = { label: "field-label", description: "field-description", group: "field-group", legend: "field-legend",
              separator: "field-separator", set: "field-set", content: "field-content", title: "field-label" }.freeze

  def html(**, &block)
    Chadcn::Field.new(**).call(&block || proc { |_| "Body" })
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

  test "every helper renders the same HTML as the explicit class" do
    helpers = html { |f| HELPERS.each_key { |n| f.public_send(n, class: "k") { "x" } } }
    explicit = html do |f|
      HELPERS.each_key { |n| f.render Chadcn::Field.const_get(n.to_s.capitalize).new(class: "k") { "x" } }
    end

    assert_equal explicit, helpers
    HELPERS.each_value { |slot| assert_includes helpers, %(data-slot="#{slot}") }
  end

  test "error helper renders the same HTML as the explicit class" do
    helpers = html { |f| f.error(errors: [ { "message" => "a" } ]) }
    explicit = html { |f| f.render Chadcn::Field::Error.new(errors: [ { "message" => "a" } ]) }

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

  test "every orientation renders its classes and data attribute" do
    Chadcn::Field::ORIENTATIONS.each_key do |name|
      root = Nokogiri::HTML5.fragment(html(orientation: name)).at_css("[data-slot=field]")

      assert_equal name, root["data-orientation"]
      assert_equal Chadcn::Field.variants(orientation: name).split.sort, root["class"].split.sort
    end
  end

  test "nil orientation falls back to vertical" do
    assert_includes html(orientation: nil), 'data-orientation="vertical"'
    assert_equal Chadcn::Field.variants, Chadcn::Field.variants(orientation: nil)
  end

  test "variants merges extra classes last" do
    assert_includes Chadcn::Field.variants(class: "gap-1"), "gap-1"
    assert_not_includes Chadcn::Field.variants(class: "gap-1"), "gap-3"
  end

  test "legend variant defaults to legend and accepts label" do
    assert_includes html { |f| f.legend { "L" } }, 'data-variant="legend"'
    assert_includes html { |f| f.legend(variant: :label) { "L" } }, 'data-variant="label"'
  end

  test "label forwards html_for to the label component" do
    out = html { |f| f.label(html_for: "email") { "Email" } }

    assert_includes out, "<label"
    assert_includes out, 'for="email"'
  end

  test "error block content wins over errors and renders nothing when empty" do
    out = html { |f| f.error(errors: [ { message: "a" } ]) { "custom" } }

    assert_includes out, ">custom</div>"
    assert_not_includes out, ">a<"
    assert_not_includes html(&:error), "field-error"
  end

  test "error accepts objects that respond to message" do
    error = Struct.new(:message).new("boom")

    assert_includes html { |f| f.error(errors: [ error ]) }, ">boom</div>"
  end
end

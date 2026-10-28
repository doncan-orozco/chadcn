# frozen_string_literal: true

require "chadcn/form/support"

class Chadcn::Form::FieldTest < Chadcn::TestCase
  include Chadcn::FormSupport

  Part = Chadcn::Form::Field

  def plain(**) = Chadcn::Form::Binding::Plain.new(scope: :user, **)

  test "readers derive ids from the binding" do
    field = Chadcn::Form::Field.new(attribute: :email, binding: plain(object: { email: "e" }, errors: { email: [ "m" ] }))
    field.call { |_| }

    assert_equal :email, field.attribute
    assert_equal "user[email]", field.name
    assert_equal "e", field.value
    assert_equal [ "m" ], field.errors
    assert_equal "user_email-form-item", field.form_item_id
    assert_equal "user_email-form-item-description", field.form_description_id
    assert_equal "user_email-form-item-message", field.form_message_id
  end

  test "control_attrs without and with errors" do
    valid = Chadcn::Form::Field.new(attribute: :email, binding: plain)
    invalid = Chadcn::Form::Field.new(attribute: :email, binding: plain(errors: { email: [ "m" ] }))
    [ valid, invalid ].each { |f| f.call { |_| } }

    assert_equal "false", valid.control_attrs.dig(:aria, :invalid)
    assert_equal "user_email-form-item-description", valid.control_attrs.dig(:aria, :describedby)
    assert_equal "true", invalid.control_attrs.dig(:aria, :invalid)
    assert_equal "user_email-form-item-description user_email-form-item-message", invalid.control_attrs.dig(:aria, :describedby)
  end

  test "the root keeps caller data and adds invalid only with errors" do
    out = Chadcn::Form::Field.new(attribute: :email, binding: plain(errors: { email: [ "m" ] }), data: { x: "1" }).call { |_| }
    root = Nokogiri::HTML5.fragment(out).at_css("[data-slot=field]")

    assert_equal "true", root["data-invalid"]
    assert_equal "1", root["data-x"]
  end

  test "is a Chadcn::Field and restores the field context" do
    ctx = {}
    Chadcn::Form::Field.new(attribute: :email, binding: plain).call(context: ctx) { |_| }

    assert_operator Chadcn::Form::Field, :<, Chadcn::Field
    assert_raises(ArgumentError) { Chadcn::Form::Field::Input.new.call(context: ctx) }
  end

  test "form_binding is the given binding and binding no longer shadows Kernel" do
    given = plain
    field = Chadcn::Form::Field.new(attribute: :email, binding: given)

    assert_same given, field.form_binding
    assert_not Chadcn::Form::Field.public_method_defined?(:binding)
  end

  test "errors are memoized and frozen" do
    field = Chadcn::Form::Field.new(attribute: :email, binding: plain(errors: { email: [ "m" ] }))

    assert_same field.errors, field.errors
    assert_predicate field.errors, :frozen?
  end

  test "the helpers render the same HTML as the explicit parts" do
    { label: Part::Label, description: Part::Description, error: Part::Error, input: Part::Input, textarea: Part::Textarea }.each do |name, part|
      helper = field_for(errors: { email: [ "bad" ] }).call { |field| field.public_send(name, class: "k") { "T" } }
      explicit = field_for(errors: { email: [ "bad" ] }).call { |field| field.render(part.new(class: "k")) { "T" } }

      assert_equal explicit, helper, name.to_s
    end
  end

  test "the bound label helper shadows the inherited one" do
    out = field_for.call(&:label)

    assert_includes out, 'for="user_email-form-item"'
  end

  test "the control helper yields the same attrs as the explicit part" do
    via_helper = nil
    via_part = nil
    field_for(errors: { email: [ "bad" ] }).call { |field| field.control(data: { k: "v" }) { |attrs| via_helper = attrs } }
    field_for(errors: { email: [ "bad" ] }).call do |field|
      field.render(Part::Control.new(data: { k: "v" })) { |attrs| via_part = attrs }
    end

    assert_equal via_part, via_helper
    assert_equal "true", via_helper[:aria][:invalid]
  end

  test "a failed render restores the field context for a sibling" do
    ctx = {}
    assert_raises(RuntimeError) { field_for.call(context: ctx) { |_| raise "boom" } }
    out = field_for.call(context: ctx, &:input)

    assert_equal "user[email]", doc(out).at_css("input")["name"]
    assert_raises(ArgumentError) { Part::Input.new.call(context: ctx) }
  end
end

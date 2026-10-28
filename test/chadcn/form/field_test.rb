# frozen_string_literal: true

require "chadcn/test_case"
require "nokogiri"

class Chadcn::Form::FieldTest < Chadcn::TestCase
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
    assert_nil ctx[Chadcn::Form::Field::FIELD_KEY]
  end
end

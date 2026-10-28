# frozen_string_literal: true

require "chadcn/form/support"

class Chadcn::Form::Field::InputGroupTest < Chadcn::TestCase
  include Chadcn::FormSupport

  Part = Chadcn::Form::Field::InputGroup

  def render_group(errors: {}, object: { email: "e", bio: "b" }, **, &block)
    block ||= :input.to_proc
    render_part(Part, errors:, object:, **, &block)
  end

  test "renders the group and binds group.input" do
    html = doc(render_group)
    input = html.at_css("[data-slot=input-group] input[data-slot=input-group-control]")

    assert_equal "group", html.at_css("[data-slot=input-group]")["role"]
    assert_equal "user[email]", input["name"]
    assert_equal "e", input["value"]
    assert_equal "user_email-form-item", input["id"]
    assert_equal "false", input["aria-invalid"]
    assert_equal "user_email-form-item-description", input["aria-describedby"]
  end

  test "errors mark the control invalid" do
    input = doc(render_group(errors: { email: [ "x" ] })).at_css("input")

    assert_equal "true", input["aria-invalid"]
    assert_equal "user_email-form-item-description user_email-form-item-message", input["aria-describedby"]
  end

  test "group.textarea is bound too and the other parts are untouched" do
    html = doc(render_group do |group|
      group.addon { "@" }
      group.textarea
    end)
    area = html.at_css("textarea[data-slot=input-group-control]")

    assert_equal "user[email]", area["name"]
    assert_equal "user_email-form-item", area["id"]
    assert_equal "@", html.at_css("[data-slot=input-group-addon]").text.strip
  end

  test "values are stringified and nil stays nil" do
    assert_equal "false", doc(render_group(object: { email: false })).at_css("input")["value"]
    assert_nil doc(render_group(object: { email: nil })).at_css("input")["value"]
  end

  test "attrs of the group and of the control win" do
    html = doc(render_group(class: "w-9") { |group| group.input(id: "mine", name: "custom", type: "email") })
    input = html.at_css("input")

    assert_includes html.at_css("[data-slot=input-group]")["class"], "w-9"
    assert_equal "mine", input["id"]
    assert_equal "custom", input["name"]
    assert_equal "email", input["type"]
    assert_equal "user_email-form-item-description", input["aria-describedby"]
  end

  test "an input group outside the part is not bound" do
    assert_nil doc(Chadcn::InputGroup.new.call(&:input)).at_css("input")["name"]
  end

  test "outside a Field the part and the bound controls raise" do
    assert_includes assert_raises(ArgumentError) { Part.new.call }.message, "must be rendered inside Chadcn::Form::Field"

    %i[input textarea].each do |name|
      group = Chadcn::InputGroup.new.extend(Chadcn::Form::Field::GroupControls)
      error = assert_raises(ArgumentError) { group.call { group.public_send(name) } }

      assert_includes error.message, "must be rendered inside Chadcn::Form::Field"
    end
  end

  test "the helper renders the same HTML as the explicit part" do
    block = :input.to_proc

    assert_equal(render_group(&block), field_for.call { |field| field.input_group(&block) })
  end
end

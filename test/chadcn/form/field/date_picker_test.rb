# frozen_string_literal: true

require "chadcn/form/support"

class Chadcn::Form::Field::DatePickerTest < Chadcn::TestCase
  include Chadcn::FormSupport

  Part = Chadcn::Form::Field::DatePicker

  def render_picker(errors: {}, object: { email: Date.new(2026, 3, 10) }, **) = render_part(Part, errors:, object:, **)

  test "renders the hidden input, the labelled trigger and the calendar" do
    html = doc(render_picker)
    hidden = html.at_css("input[type=hidden]")
    button = html.at_css("button[data-slot=popover-trigger]")
    label = html.at_css("#user_email-form-item-label")

    assert_equal "user[email]", hidden["name"]
    assert_equal "2026-03-10", hidden["value"]
    assert_equal "user_email-form-item-value", hidden["id"]
    assert_equal "user_email-form-item", button["id"]
    assert_equal "false", button["aria-invalid"]
    assert_equal "user_email-form-item-description", button["aria-describedby"]
    assert_equal "outline", button["data-variant"]
    assert_equal "March 10th, 2026", label.text
    assert_equal "false", label["data-empty"]
    assert_equal "Pick a date", label["data-chadcn--calendar-placeholder"]
    assert_includes html.to_html, "#user_email-form-item-value"
    assert_includes html.to_html, "#user_email-form-item-label"
  end

  test "the hidden input is outside the popover content" do
    html = doc(render_picker)

    assert_empty html.css("template input[type=hidden], [data-slot=popover-content] input[type=hidden]").to_a
    assert_equal 1, html.css("input[type=hidden]").size
  end

  test "errors mark the trigger invalid" do
    button = doc(render_picker(errors: { email: [ "x" ] })).at_css("button")

    assert_equal "true", button["aria-invalid"]
    assert_equal "user_email-form-item-description user_email-form-item-message", button["aria-describedby"]
  end

  test "a nil value shows the placeholder and omits the hidden value" do
    html = doc(render_picker(object: { email: nil }, placeholder: "Choose"))
    label = html.at_css("#user_email-form-item-label")

    assert_equal "Choose", label.text
    assert_equal "true", label["data-empty"]
    assert_equal "Choose", label["data-chadcn--calendar-placeholder"]
    assert_nil html.at_css("input[type=hidden]")["value"]
  end

  test "casts Date, Time, DateTime and ISO strings, blank is empty" do
    [ Date.new(2026, 1, 2), Time.new(2026, 1, 2, 10), DateTime.new(2026, 1, 2, 10), "2026-01-02" ].each do |value|
      assert_equal "2026-01-02", doc(render_picker(object: { email: value })).at_css("input[type=hidden]")["value"], value.inspect
    end
    assert_nil doc(render_picker(object: { email: "" })).at_css("input[type=hidden]")["value"]
  end

  test "the ordinal suffix follows the English rules" do
    { 1 => "1st", 2 => "2nd", 3 => "3rd", 4 => "4th", 11 => "11th", 12 => "12th", 13 => "13th", 21 => "21st", 22 => "22nd" }.each do |day, text|
      label = doc(render_picker(object: { email: Date.new(2026, 3, day) })).at_css("#user_email-form-item-label")

      assert_equal "March #{text}, 2026", label.text
    end
  end

  test "caller attrs merge onto the button and calendar options onto the calendar" do
    html = doc(render_picker(id: "mine", class: "w-1", disabled: true, calendar: { week_starts_on: 1 }))
    button = html.at_css("button")

    assert_equal "mine", button["id"]
    assert_includes button["class"], "w-1"
    assert button.key?("disabled")
    calendar = html.css("[data-controller~='chadcn--calendar']").first

    assert_equal 1, JSON.parse(calendar["data-chadcn--calendar-config-value"])["weekStartsOn"]
  end

  test "a disabled picker disables the hidden input too" do
    assert doc(render_picker(disabled: true)).at_css("input[type=hidden]").key?("disabled")
    refute doc(render_picker).at_css("input[type=hidden]").key?("disabled")
  end

  test "outside a Field it raises" do
    error = assert_raises(ArgumentError) { Part.new.call }

    assert_includes error.message, "must be rendered inside Chadcn::Form::Field"
  end

  test "values it cannot express raise with the attribute" do
    [ "2026-13-45", "March 10", [ 1 ], 5, { a: 1 } ].each do |value|
      error = assert_raises(ArgumentError) { render_picker(object: { email: value }) }

      assert_includes error.message, "Chadcn::Form::Field::DatePicker"
      assert_includes error.message, ":email"
    end
  end

  test "the helper renders the same HTML as the explicit part" do
    assert_equal(render_picker(placeholder: "X"), field_for(object: { email: Date.new(2026, 3, 10) }).call { |field| field.date_picker(placeholder: "X") })
  end
end

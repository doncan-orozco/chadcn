# frozen_string_literal: true

require "chadcn/form/support"

class Chadcn::Form::Field::SliderTest < Chadcn::TestCase
  include Chadcn::FormSupport

  Part = Chadcn::Form::Field::Slider

  def render_slider(errors: {}, object: { email: 40 }, **) = render_part(Part, errors:, object:, **)

  test "binds id and aria on the root and the name on the hidden input" do
    html = doc(render_slider)
    root = html.at_css("[data-slot=slider]")

    assert_equal "user_email-form-item", root["id"]
    assert_equal "false", root["aria-invalid"]
    assert_equal "user_email-form-item-description", root["aria-describedby"]
    assert_equal "user[email]", html.at_css("input")["name"]
    assert_equal "40", html.at_css("input")["value"]
    assert_equal "40", html.at_css("[role=slider]")["aria-valuenow"]
  end

  test "errors mark the root invalid" do
    root = doc(render_slider(errors: { email: [ "x" ] })).at_css("[data-slot=slider]")

    assert_equal "true", root["aria-invalid"]
    assert_equal "user_email-form-item-description user_email-form-item-message", root["aria-describedby"]
  end

  test "an array of numbers renders one thumb each" do
    html = doc(render_slider(object: { email: [ 10, 20.5 ] }))

    assert_equal 2, html.css("[role=slider]").size
    assert_equal(%w[10 20.5], html.css("[role=slider]").map { |thumb| thumb["aria-valuenow"] })
    assert_equal "user[email][]", html.at_css("input")["name"]
  end

  test "a nil value falls back to the component default" do
    assert_equal doc(render_part(Part, object: { email: nil })).css("[role=slider]").size,
                 doc(Chadcn::Slider.new.call).css("[role=slider]").size
  end

  test "caller attrs win" do
    html = doc(render_slider(id: "mine", name: "custom", default_value: [ 5 ], max: 10, class: "w-9"))
    root = html.at_css("[data-slot=slider]")

    assert_equal "mine", root["id"]
    assert_equal "10", root["data-chadcn--slider-max-value"]
    assert_includes root["class"], "w-9"
    assert_equal "5", root.at_css("[role=slider]")["aria-valuenow"]
    assert_equal "custom", html.at_css("input")["name"]
    assert_equal 1, html.css("[role=slider]").size
  end

  test "values the slider cannot express raise with the attribute" do
    [ "40", [ 1, "2" ], { a: 1 }, true ].each do |value|
      error = assert_raises(ArgumentError) { render_slider(object: { email: value }) }

      assert_includes error.message, "Chadcn::Form::Field::Slider"
      assert_includes error.message, ":email"
    end
  end

  test "the helper renders the same HTML as the explicit part" do
    assert_equal(render_slider, field_for(object: { email: 40 }).call(&:slider))
  end
end

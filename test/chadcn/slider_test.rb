# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::SliderTest < Chadcn::TestCase
  Slider = Chadcn::Slider

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def slider(**props) = fragment(render_view { render(Slider.new(**props)) })

  test "root renders radix attributes, slot and merged class" do
    root = slider(default_value: [ 25, 75 ], class: "w-[300px]", id: "vol", aria: { label: "Volume" }).at_css("[data-slot=slider]")

    assert_equal "ltr", root["dir"]
    assert_equal "false", root["aria-disabled"]
    assert_equal "horizontal", root["data-orientation"]
    assert_includes root["class"], "w-[300px]"
    refute_includes root["class"], "w-full"
    assert_equal "vol", root["id"]
    assert_equal "Volume", root["aria-label"]
    assert_equal "--radix-slider-thumb-transform: translateX(-50%);", root["style"]
  end

  test "range and thumbs follow the values" do
    doc = slider(default_value: [ 25, 75 ])
    thumbs = doc.css("[role=slider]")

    assert_equal "left: 25%; right: 25%;", doc.at_css("[data-slot=slider-range]")["style"]
    assert_equal(%w[25 75], thumbs.map { |t| t["aria-valuenow"] })
    assert_equal(%w[Minimum Maximum], thumbs.map { |t| t["aria-label"] })
    assert_includes thumbs.first.parent["style"], "left: calc(25% + 0px)"
  end

  test "thumb names default to the React strings and can be overridden" do
    names = ->(**props) { slider(**props).css("[role=slider]").map { |t| t["aria-label"] } }

    assert_equal(%w[Minimum Maximum], names.call(default_value: [ 1, 2 ]))
    assert_equal([ "Value 1 of 3", "Value 2 of 3", "Value 3 of 3" ], names.call(default_value: [ 1, 2, 3 ]))
    assert_equal(%w[Mínimo Máximo], names.call(default_value: [ 1, 2 ], min_label: "Mínimo", max_label: "Máximo"))
    assert_equal([ "1/3", "2/3", "3/3" ], names.call(default_value: [ 1, 2, 3 ], value_label: "%<index>d/%<count>d"))
  end

  test "no values renders two thumbs and hides the second" do
    thumbs = slider.css("[role=slider]")

    assert_equal 2, thumbs.size
    assert_equal "display: none;", thumbs.last["style"]
    assert_nil thumbs.last["aria-valuenow"]
    assert_equal "0", thumbs.first["aria-valuenow"]
  end

  test "disabled and vertical" do
    doc = slider(default_value: [ 30 ], disabled: true, orientation: :vertical, dir: "rtl")
    root = doc.at_css("[data-slot=slider]")

    assert_equal "true", root["aria-disabled"]
    assert_equal "", root["data-disabled"]
    assert_equal "rtl", root["dir"]
    assert_nil doc.at_css("[role=slider]")["tabindex"]
    assert_equal "bottom: 0%; top: 70%;", doc.at_css("[data-slot=slider-range]")["style"]
    assert_raises(ArgumentError) { slider(orientation: "diagonal") }
  end

  test "bubble inputs carry name and value" do
    inputs = slider(default_value: [ 20, 80 ], name: "price").css("input")

    assert_equal(%w[price[] price[]], inputs.map { |i| i["name"] })
    assert_equal(%w[20 80], inputs.map { |i| i["value"] })
  end

  test "dir resolves from the direction provider and a local dir wins" do
    provided = render_view { render(Chadcn::Direction::Provider.new(dir: "rtl")) { render(Slider.new(default_value: [ 10 ])) } }
    local = render_view { render(Chadcn::Direction::Provider.new(dir: "rtl")) { render(Slider.new(default_value: [ 10 ], dir: "ltr")) } }

    assert_equal "rtl", fragment(provided).at_css("[data-slot=slider]")["dir"]
    assert_equal "ltr", fragment(local).at_css("[data-slot=slider]")["dir"]
    assert_includes fragment(provided).at_css("[data-slot=slider-range]")["style"], "right: 0%; left: 90%;"
  end

  test "unknown dir raises and controlled value is flagged" do
    assert_raises(ArgumentError) { slider(dir: "up") }
    assert_equal "true", slider(value: [ 10 ]).at_css("[data-slot=slider]")["data-shadcn--slider-controlled-value"]
    assert_equal "false", slider(default_value: [ 10 ]).at_css("[data-slot=slider]")["data-shadcn--slider-controlled-value"]
  end

  test "constant tables" do
    assert_equal %w[horizontal vertical], Slider::ORIENTATIONS
    assert_equal %w[ltr rtl], Slider::DIRECTIONS
  end

  test "more than two thumbs get numbered labels and the name[] input name" do
    doc = slider(default_value: [ 1, 2, 3 ], name: "n")

    assert_equal([ "Value 1 of 3", "Value 2 of 3", "Value 3 of 3" ], doc.css("[role=slider]").map { |t| t["aria-label"] })
    assert_equal(%w[n[] n[] n[]], doc.css("input").map { |i| i["name"] })
  end

  test "a non-Array value is ignored and the slider stays uncontrolled" do
    doc = slider(value: "x", default_value: [ 10 ])

    assert_equal "false", doc.at_css("[data-slot=slider]")["data-shadcn--slider-controlled-value"]
    assert_equal "10", doc.at_css("[role=slider]")["aria-valuenow"]
  end

  test "with no values two inputs share the plain name and only the first has a value" do
    inputs = slider(name: "n").css("input")

    assert_equal(%w[n n], inputs.map { |i| i["name"] })
    assert_equal "0", inputs.first["value"]
    assert_nil inputs.last["value"]
  end

  test "min max step inverted steps order and form reach the controller and inputs" do
    doc = slider(default_value: [ 25 ], min: 10, max: 50, step: 5, inverted: true, min_steps_between_thumbs: 2,
                 preserve_thumb_order: true, form: "f", name: "n")
    root = doc.at_css("[data-slot=slider]")

    assert_equal "10", root["data-shadcn--slider-min-value"]
    assert_equal "50", root["data-shadcn--slider-max-value"]
    assert_equal "5", root["data-shadcn--slider-step-value"]
    assert_equal "true", root["data-shadcn--slider-inverted-value"]
    assert_equal "2", root["data-shadcn--slider-min-steps-between-thumbs-value"]
    assert_equal "true", root["data-shadcn--slider-preserve-thumb-order-value"]
    assert_equal "f", root["data-shadcn--slider-form-value"]
    assert_equal "f", doc.at_css("input")["form"]
    assert_equal "right: 0%; left: 62.5%;", doc.at_css("[data-slot=slider-range]")["style"]
    assert_equal "25", doc.at_css("[role=slider]")["aria-valuenow"]
  end
end

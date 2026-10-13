# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::SliderTest < Phlex::Shadcn::TestCase
  Slider = Phlex::Shadcn::Slider

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
    provided = render_view { render(Phlex::Shadcn::Direction::Provider.new(dir: "rtl")) { render(Slider.new(default_value: [ 10 ])) } }
    local = render_view { render(Phlex::Shadcn::Direction::Provider.new(dir: "rtl")) { render(Slider.new(default_value: [ 10 ], dir: "ltr")) } }

    assert_equal "rtl", fragment(provided).at_css("[data-slot=slider]")["dir"]
    assert_equal "ltr", fragment(local).at_css("[data-slot=slider]")["dir"]
    assert_includes fragment(provided).at_css("[data-slot=slider-range]")["style"], "right: 0%; left: 90%;"
  end
end

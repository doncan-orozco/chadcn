# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::InputGroupTest < Chadcn::TestCase
  IG = Chadcn::InputGroup

  def render_part(part, **, &block)
    part.new(**).call(&block || proc { "x" })
  end

  test "root renders slot, role, merged class and passthrough attrs" do
    out = render_part(IG, class: "h-12", id: "g", "data-disabled": "true")

    assert_includes out, 'data-slot="input-group"'
    assert_includes out, 'role="group"'
    assert_includes out, "h-12"
    assert_not_includes Nokogiri::HTML5.fragment(out).at_css("[data-slot=input-group]")["class"].split, "h-9"
    assert_includes out, 'id="g"'
    assert_includes out, 'data-disabled="true"'
  end

  test "addon aligns, normalizes symbols and wires the controller" do
    out = render_part(IG::Addon, align: :inline_end)

    assert_includes out, 'data-align="inline-end"'
    assert_includes out, 'data-slot="input-group-addon"'
    assert_includes out, 'data-controller="chadcn--input-group"'
    assert_includes out, 'data-action="click->chadcn--input-group#focusControl"'
    assert_includes render_part(IG::Addon, align: "block-start"), "w-full justify-start"
    assert_raises(ArgumentError) { render_part(IG::Addon, align: "middle") }
  end

  test "caller click action replaces the focus handler, other actions are kept" do
    replaced = render_part(IG::Addon, data: { action: "click->x#y" })
    kept = render_part(IG::Addon, data: { action: "keydown->x#y" })

    assert_not_includes replaced, "focusControl"
    assert_includes kept, "keydown->x#y click->chadcn--input-group#focusControl"
  end

  test "button defaults to ghost xs and forwards size data" do
    out = render_part(IG::Button)

    assert_includes out, 'data-slot="button"'
    assert_includes out, 'data-variant="ghost"'
    assert_includes out, 'data-size="xs"'
    assert_includes out, 'type="button"'
    assert_includes render_part(IG::Button, size: :icon_sm, variant: :outline), 'data-size="icon-sm"'
    assert_raises(ArgumentError) { render_part(IG::Button, size: "lg") }
  end

  test "text has no slot, input and textarea use the control slot" do
    assert_not_includes render_part(IG::Text), "data-slot"
    assert_includes render_part(IG::Input, placeholder: "p"), 'data-slot="input-group-control"'
    assert_includes render_part(IG::Textarea), 'data-slot="input-group-control"'
  end

  test "every helper renders the same HTML as the explicit class" do
    { addon: IG::Addon, button: IG::Button, text: IG::Text, input: IG::Input, textarea: IG::Textarea }.each do |helper, part|
      via_helper = IG.new.call { |group| group.public_send(helper, class: "k") }
      explicit = IG.new.call { |group| group.render part.new(class: "k") }

      assert_equal explicit, via_helper, helper.to_s
    end
  end

  test "every addon alignment renders its classes" do
    IG::Addon::ALIGNS.each do |align, classes|
      out = render_part(IG::Addon, align:)

      assert_includes out, %(data-align="#{align}")
      assert_includes out, classes.split.first
    end
  end

  test "every button size renders its classes" do
    IG::Button::SIZES.each do |size, classes|
      out = render_part(IG::Button, size:)

      assert_includes out, %(data-size="#{size}")
      assert_includes out, classes.split.first
    end
  end

  test "button as_child renders the given tag" do
    out = render_part(IG::Button, as_child: :a, href: "/x")

    assert_includes out, "<a "
    assert_includes out, 'href="/x"'
  end

  test "input and textarea forward their attributes" do
    assert_includes render_part(IG::Input, type: "email", placeholder: "p"), 'type="email"'
    assert_includes render_part(IG::Textarea, rows: 3) { "t" }, 'rows="3"'
  end

  test "text merges the caller class" do
    assert_includes render_part(IG::Text, class: "font-mono"), "font-mono"
  end
end

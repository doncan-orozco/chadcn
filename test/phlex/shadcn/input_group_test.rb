# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::InputGroupTest < Phlex::Shadcn::TestCase
  IG = Phlex::Shadcn::InputGroup

  def render_part(part, **, &block)
    part.new(**).call(&block || proc { "x" })
  end

  test "root renders slot, role, merged class and passthrough attrs" do
    out = render_part(IG, class: "h-12", id: "g", "data-disabled": "true")

    assert_includes out, 'data-slot="input-group"'
    assert_includes out, 'role="group"'
    assert_includes out, "h-12"
    assert_not_includes out, " h-9 "
    assert_includes out, 'id="g"'
    assert_includes out, 'data-disabled="true"'
  end

  test "addon aligns, normalizes symbols and wires the controller" do
    out = render_part(IG::Addon, align: :inline_end)

    assert_includes out, 'data-align="inline-end"'
    assert_includes out, 'data-slot="input-group-addon"'
    assert_includes out, 'data-controller="shadcn--input-group"'
    assert_includes out, 'data-action="click->shadcn--input-group#focusControl"'
    assert_includes render_part(IG::Addon, align: "block-start"), "w-full justify-start"
    assert_raises(ArgumentError) { render_part(IG::Addon, align: "middle") }
  end

  test "caller click action replaces the focus handler, other actions are kept" do
    replaced = render_part(IG::Addon, data: { action: "click->x#y" })
    kept = render_part(IG::Addon, data: { action: "keydown->x#y" })

    assert_not_includes replaced, "focusControl"
    assert_includes kept, "keydown->x#y click->shadcn--input-group#focusControl"
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
    assert_includes render_part(IG::Input, placeholder: "p", class: "w-1"), 'data-slot="input-group-control"'
    assert_includes render_part(IG::Textarea, default_value: "hi"), 'data-slot="input-group-control"'
  end

  test "every helper renders the same HTML as the explicit class" do
    { addon: IG::Addon, button: IG::Button, text: IG::Text, input: IG::Input, textarea: IG::Textarea }.each do |helper, part|
      via_helper = IG.new.call { |group| group.public_send(helper, class: "k") }
      explicit = IG.new.call { |group| group.render part.new(class: "k") }

      assert_equal explicit, via_helper, helper.to_s
    end
  end
end

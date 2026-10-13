# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::MenubarTest < Phlex::Shadcn::TestCase
  Menubar = Phlex::Shadcn::Menubar

  HELPERS = {
    portal: Menubar::Portal, menu: Menubar::Menu, trigger: Menubar::Trigger, content: Menubar::Content,
    group: Menubar::Group, separator: Menubar::Separator, label: Menubar::Label, item: Menubar::Item,
    shortcut: Menubar::Shortcut, checkbox_item: Menubar::CheckboxItem, radio_group: Menubar::RadioGroup,
    radio_item: Menubar::RadioItem, sub: Menubar::Sub, sub_trigger: Menubar::SubTrigger, sub_content: Menubar::SubContent
  }.freeze

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def bar(root: {}, trigger: {}, content: {}, &body)
    render_view do
      render(Menubar.new(**root)) do
        render(Menubar::Menu.new(value: "file")) do
          render(Menubar::Trigger.new(**trigger)) { "File" }
          render(Menubar::Content.new(**content)) { body ? instance_exec(&body) : render(Menubar::Item.new) { "New" } }
        end
      end
    end
  end

  test "root renders the menubar with its controller values and no dir attribute" do
    root = fragment(bar(root: { dir: :rtl, class: "mx-4", id: "mb" })).at_css("[data-slot=menubar]")

    assert_equal "menubar", root["role"]
    assert_equal "horizontal", root["data-orientation"]
    assert_equal "shadcn--menubar", root["data-controller"]
    assert_equal "rtl", root["data-shadcn--menubar-dir-value"]
    assert_equal "mb", root["id"]
    assert_nil root["dir"]
    assert_includes root["class"], "mx-4"
    assert_includes root["class"], "h-9"
  end

  test "closed menu renders the trigger and the content inside an inert template" do
    doc = fragment(bar)
    trigger = doc.at_css("button[data-slot=menubar-trigger]")

    assert_equal "menuitem", trigger["role"]
    assert_equal "false", trigger["aria-expanded"]
    assert_equal "closed", trigger["data-state"]
    assert_nil trigger["aria-controls"]

    content = doc.at_css("template[data-shadcn--menubar-template] [data-slot=menubar-content]")

    assert_equal trigger["id"], content["aria-labelledby"]
    assert_equal "", content["data-radix-menubar-content"]
    assert_includes content["style"], "--radix-menubar-trigger-width: var(--radix-popper-anchor-width)"
  end

  test "default_value opens the matching menu and a controlled value is honoured" do
    trigger = fragment(bar(root: { default_value: "file" })).at_css("[data-slot=menubar-trigger]")

    assert_equal "open", trigger["data-state"]
    assert trigger["aria-controls"]
    assert_equal "false", fragment(bar(root: { value: "edit" })).at_css("[data-slot=menubar-trigger]")["aria-expanded"]
    assert_equal "true", fragment(bar(root: { value: "edit" })).at_css("[data-slot=menubar]")["data-shadcn--menubar-controlled-value"]
  end

  test "disabled trigger" do
    trigger = fragment(bar(trigger: { disabled: true })).at_css("[data-slot=menubar-trigger]")

    assert_equal "", trigger["data-disabled"]
    assert trigger.key?("disabled")
  end

  test "item variants, inset, disabled and string or symbol options" do
    html = ->(**o) { fragment(bar { render(Menubar::Item.new(**o)) { "x" } }).at_css("[data-slot=menubar-item]") }

    assert_equal "destructive", html.call(variant: :destructive)["data-variant"]
    assert_equal "default", html.call["data-variant"]
    assert_equal "true", html.call(inset: true)["data-inset"]
    assert_nil html.call["data-inset"]
    item = html.call(disabled: true, class: "extra", data: { foo: "1" })

    assert_equal "true", item["aria-disabled"]
    assert_equal "1", item["data-foo"]
    assert_includes item["class"], "extra"
  end

  test "checkbox and radio items expose their checked state" do
    doc = fragment(bar do
      render(Menubar::CheckboxItem.new(checked: "indeterminate")) { "c" }
      render(Menubar::RadioGroup.new(value: "a")) do
        render(Menubar::RadioItem.new(value: "a")) { "A" }
        render(Menubar::RadioItem.new(value: "b")) { "B" }
      end
    end)

    assert_equal "mixed", doc.at_css("[data-slot=menubar-checkbox-item]")["aria-checked"]
    assert_equal(%w[true false], doc.css("[data-slot=menubar-radio-item]").map { |el| el["aria-checked"] })
  end

  test "sub trigger carries the chevron and the menubar marker, sub content sits in a template" do
    doc = fragment(bar do
      render(Menubar::Sub.new) do
        render(Menubar::SubTrigger.new) { "More" }
        render(Menubar::SubContent.new) { render(Menubar::Item.new) { "Deep" } }
      end
    end)
    trigger = doc.at_css("[data-slot=menubar-sub-trigger]")

    assert_equal "", trigger["data-radix-menubar-subtrigger"]
    assert trigger.at_css("svg.ml-auto")
    assert doc.at_css("template template [data-slot=menubar-sub-content]")
  end

  test "as_child renders the trigger as the given element" do
    trigger = fragment(bar(trigger: { as_child: :a, href: "/x" })).at_css("[data-slot=menubar-trigger]")

    assert_equal "a", trigger.name
    assert_equal "/x", trigger["href"]
  end

  test "every part has a generated helper on the root rendering the same HTML" do
    HELPERS.each_key { |helper| assert_includes Menubar.public_instance_methods(false), helper }
    HELPERS.each do |helper, klass|
      args = klass == Menubar::RadioItem ? { value: "v" } : {}
      explicit = render_view { render(Menubar.new) { render(Menubar::Menu.new) { render(Menubar::Sub.new) { render(klass.new(**args)) { "x" } } } } }
      generated = render_view do
        render(Menubar.new) { |root| render(Menubar::Menu.new) { render(Menubar::Sub.new) { root.public_send(helper, **args) { "x" } } } }
      end

      assert_equal explicit, generated, "helper #{helper}"
    end
  end
end

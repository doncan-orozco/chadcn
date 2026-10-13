# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::ContextMenuTest < Phlex::Shadcn::TestCase
  ContextMenu = Phlex::Shadcn::ContextMenu

  HELPERS = {
    trigger: ContextMenu::Trigger, content: ContextMenu::Content, item: ContextMenu::Item,
    checkbox_item: ContextMenu::CheckboxItem, radio_item: ContextMenu::RadioItem, label: ContextMenu::Label,
    separator: ContextMenu::Separator, shortcut: ContextMenu::Shortcut, group: ContextMenu::Group,
    portal: ContextMenu::Portal, sub: ContextMenu::Sub, sub_content: ContextMenu::SubContent,
    sub_trigger: ContextMenu::SubTrigger, radio_group: ContextMenu::RadioGroup
  }.freeze

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def menu(root: {}, trigger: {}, content: {}, &body)
    render_view do
      render(ContextMenu.new(**root)) do
        render(ContextMenu::Trigger.new(**trigger)) { "Right click" }
        render(ContextMenu::Content.new(**content)) { body ? instance_exec(&body) : render(ContextMenu::Item.new) { "Back" } }
      end
    end
  end

  test "trigger is a bare span hosting the controller" do
    trigger = fragment(menu).at_css("[data-slot=context-menu-trigger]")

    assert_equal "span", trigger.name
    assert_equal "closed", trigger["data-state"]
    assert_equal "shadcn--context-menu", trigger["data-controller"]
    assert_equal "-webkit-touch-callout: none", trigger["style"]
    %w[id aria-haspopup aria-expanded type tabindex class].each { |name| assert_nil trigger[name], name }
  end

  test "trigger keeps the caller class verbatim and appends the caller style" do
    trigger = fragment(menu(trigger: { class: "rounded-md rounded-full", style: "color: red",
                                       disabled: true })).at_css("[data-slot=context-menu-trigger]")

    assert_equal "rounded-md rounded-full", trigger["class"]
    assert_equal "-webkit-touch-callout: none; color: red", trigger["style"]
    assert trigger.key?("data-disabled")
    assert_not trigger.key?("disabled")
  end

  test "content ships in a template with forced placement and no id" do
    template = fragment(menu(content: { class: "w-64" })).at_css("template[data-shadcn--dropdown-menu-template]")
    content = template.at_css("[data-slot=context-menu-content]")
    options = JSON.parse(template["data-options"])

    assert_equal "menu", content["role"]
    assert_nil content["id"]
    assert_nil content["aria-labelledby"]
    assert_includes content["class"], "w-64"
    assert_includes content["style"], "--radix-context-menu-trigger-width: var(--radix-popper-anchor-width)"
    assert_equal({ "side" => "right", "sideOffset" => 2, "align" => "start" }, options.slice("side", "sideOffset", "align"))
  end

  test "side, side_offset and align are not options of the root content" do
    %i[side side_offset align].each { |name| assert_raises(ArgumentError) { ContextMenu::Content.new(name => "x") } }
    assert_raises(ArgumentError) { ContextMenu.new(default_open: true) }
  end

  test "controlled open root marks the trigger open" do
    trigger = fragment(menu(root: { open: true })).at_css("[data-slot=context-menu-trigger]")

    assert_equal "open", trigger["data-state"]
    assert_equal "true", trigger["data-shadcn--context-menu-controlled-value"]
  end

  test "item variants, inset and disabled" do
    html = menu do
      render(ContextMenu::Item.new(variant: :destructive, inset: true, disabled: true)) { "Delete" }
    end
    item = fragment(html).at_css("template [data-slot=context-menu-item]")

    assert_equal "destructive", item["data-variant"]
    assert_equal "true", item["data-inset"]
    assert_equal "true", item["aria-disabled"]
    assert_equal "menuitem", item["role"]
  end

  test "checkbox and radio items expose their state" do
    html = menu do
      render(ContextMenu::CheckboxItem.new(checked: "indeterminate")) { "Bookmarks" }
      render(ContextMenu::RadioGroup.new(value: "a", class: "p-1 p-2")) do
        render(ContextMenu::RadioItem.new(value: "a")) { "A" }
        render(ContextMenu::RadioItem.new(value: "b")) { "B" }
      end
    end
    doc = fragment(html)

    assert_equal "mixed", doc.at_css("[data-slot=context-menu-checkbox-item]")["aria-checked"]
    assert_equal "p-1 p-2", doc.at_css("[data-slot=context-menu-radio-group]")["class"]
    assert_equal(%w[true false], doc.css("[data-slot=context-menu-radio-item]").map { |el| el["aria-checked"] })
  end

  test "sub wires trigger and content ids" do
    html = menu do
      render(ContextMenu::Sub.new) do
        render(ContextMenu::SubTrigger.new) { "More" }
        render(ContextMenu::SubContent.new) { render(ContextMenu::Item.new) { "Save" } }
      end
    end
    doc = fragment(html)
    trigger = doc.at_css("[data-slot=context-menu-sub-trigger]")
    content = doc.at_css("[data-slot=context-menu-sub-content]")

    assert_equal "menu", trigger["aria-haspopup"]
    assert_equal trigger["id"], content["aria-labelledby"]
    assert_equal "false", trigger["aria-expanded"]
  end

  test "every DX helper exists and renders like the explicit class call" do
    HELPERS.each do |helper, part|
      assert_includes ContextMenu.public_instance_methods, helper
      args = helper == :radio_item ? { value: "a" } : {}
      nested = %i[sub_content sub_trigger].include?(helper)
      via_helper = render_view do
        render(ContextMenu.new) do |root|
          next root.public_send(helper, **args) { "x" } unless nested

          root.sub { root.public_send(helper, **args) { "x" } }
        end
      end
      explicit = render_view do
        render(ContextMenu.new) do
          next render(part.new(**args)) { "x" } unless nested

          render(ContextMenu::Sub.new) { render(part.new(**args)) { "x" } }
        end
      end

      assert_equal explicit, via_helper, helper.to_s
    end
  end
end

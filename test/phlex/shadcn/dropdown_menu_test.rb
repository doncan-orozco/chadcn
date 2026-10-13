# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::DropdownMenuTest < Phlex::Shadcn::TestCase
  DropdownMenu = Phlex::Shadcn::DropdownMenu

  HELPERS = {
    portal: DropdownMenu::Portal, trigger: DropdownMenu::Trigger, content: DropdownMenu::Content, group: DropdownMenu::Group,
    label: DropdownMenu::Label, item: DropdownMenu::Item, checkbox_item: DropdownMenu::CheckboxItem,
    radio_group: DropdownMenu::RadioGroup, radio_item: DropdownMenu::RadioItem, separator: DropdownMenu::Separator,
    shortcut: DropdownMenu::Shortcut, sub: DropdownMenu::Sub, sub_trigger: DropdownMenu::SubTrigger,
    sub_content: DropdownMenu::SubContent
  }.freeze

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def menu(root: {}, trigger: {}, content: {}, &body)
    render_view do
      render(DropdownMenu.new(**root)) do
        render(DropdownMenu::Trigger.new(**trigger)) { "Open" }
        render(DropdownMenu::Content.new(**content)) { body ? instance_exec(&body) : render(DropdownMenu::Item.new) { "Profile" } }
      end
    end
  end

  test "closed menu renders the trigger and the content inside an inert template" do
    doc = fragment(menu)
    trigger = doc.at_css("button[data-slot=dropdown-menu-trigger]")

    assert_equal "button", trigger["type"]
    assert_equal "menu", trigger["aria-haspopup"]
    assert_equal "false", trigger["aria-expanded"]
    assert_equal "closed", trigger["data-state"]
    assert_nil trigger["aria-controls"]
    assert_equal "shadcn--dropdown-menu", trigger["data-controller"]

    template = doc.at_css("template[data-shadcn--dropdown-menu-template]")
    content = template.at_css("[data-slot=dropdown-menu-content]")

    assert_equal "menu", content["role"]
    assert_equal "vertical", content["aria-orientation"]
    assert_equal trigger["id"], content["aria-labelledby"]
    assert_includes content["style"], "--radix-dropdown-menu-content-available-height: var(--radix-popper-available-height)"
    assert_includes content["class"], "min-w-[8rem]"
    assert_nil doc.at_css("body > [data-slot=dropdown-menu-content], :not(template) > [data-slot=dropdown-menu-content]")
  end

  test "open menu mirrors the open state on the trigger" do
    trigger = fragment(menu(root: { default_open: true })).at_css("[data-slot=dropdown-menu-trigger]")

    assert_equal "true", trigger["aria-expanded"]
    assert_equal "open", trigger["data-state"]
    assert trigger["aria-controls"]
    assert_equal "true", trigger["data-shadcn--dropdown-menu-open-value"]
    assert_equal "false", trigger["data-shadcn--dropdown-menu-controlled-value"]
  end

  test "controlled root wins over default_open and is flagged" do
    trigger = fragment(menu(root: { open: false, default_open: true })).at_css("[data-slot=dropdown-menu-trigger]")

    assert_equal "closed", trigger["data-state"]
    assert_equal "true", trigger["data-shadcn--dropdown-menu-controlled-value"]
  end

  test "root renders no element of its own and rejects unknown options" do
    assert_not_includes menu, "data-slot=\"dropdown-menu\""
    assert_raises(ArgumentError) { DropdownMenu.new(side: "top") }
  end

  test "trigger: disabled, as_child, passthrough attrs and caller id" do
    disabled = fragment(menu(trigger: { disabled: true })).at_css("[data-slot=dropdown-menu-trigger]")

    assert disabled.key?("disabled")
    assert disabled.key?("data-disabled")

    link = fragment(menu(trigger: { as_child: :a, href: "#x", id: "mine", class: "rounded-full", data: { testid: "t" } })).at_css("a")

    assert_equal "dropdown-menu-trigger", link["data-slot"]
    assert_equal "mine", link["id"]
    assert_equal "#x", link["href"]
    assert_equal "t", link["data-testid"]
    assert_equal "rounded-full", link["class"]
    assert_equal "menu", link["aria-haspopup"]
  end

  test "item: variants, inset, disabled, text_value, class merge and passthrough" do
    html = menu do
      render(DropdownMenu::Item.new { "Plain" })
      render DropdownMenu::Item.new(variant: :destructive, inset: true, class: "p-4", "aria-label": "Del") { "Delete" }
      render DropdownMenu::Item.new(inset: false, disabled: true, text_value: "Dis") { "Disabled" }
    end
    items = fragment(html).css("[data-slot=dropdown-menu-item]")
    plain, destructive, disabled = items

    assert_equal "default", plain["data-variant"]
    assert_nil plain["data-inset"]
    assert_equal "menuitem", plain["role"]
    assert_equal "-1", plain["tabindex"]
    assert_equal "vertical", plain["data-orientation"]
    assert_equal "destructive", destructive["data-variant"]
    assert_equal "true", destructive["data-inset"]
    assert_equal "Del", destructive["aria-label"]
    assert_includes destructive["class"].split, "p-4"
    assert_not_includes destructive["class"].split, "px-2"
    assert_equal "false", disabled["data-inset"]
    assert_equal "true", disabled["aria-disabled"]
    assert disabled.key?("data-disabled")
    assert_equal "Dis", disabled["data-text-value"]
  end

  test "checkbox items expose the three checked states and the indicator only when checked" do
    html = menu do
      render(DropdownMenu::CheckboxItem.new(checked: true)) { "On" }
      render(DropdownMenu::CheckboxItem.new(checked: false)) { "Off" }
      render(DropdownMenu::CheckboxItem.new(checked: "indeterminate")) { "Mixed" }
    end
    on, off, mixed = fragment(html).css("[data-slot=dropdown-menu-checkbox-item]")

    assert_equal %w[menuitemcheckbox true checked], [ on["role"], on["aria-checked"], on["data-state"] ]
    assert_equal %w[false unchecked], [ off["aria-checked"], off["data-state"] ]
    assert_equal %w[mixed indeterminate], [ mixed["aria-checked"], mixed["data-state"] ]
    assert on.at_css("span[data-state=checked] svg.lucide-check")
    assert_nil off.at_css("svg")
    assert mixed.at_css("span[data-state=indeterminate] svg.lucide-check")
  end

  test "radio items are checked when their value equals the group value" do
    html = menu do
      render DropdownMenu::RadioGroup.new(value: "b") do
        render(DropdownMenu::RadioItem.new(value: "a")) { "A" }
        render(DropdownMenu::RadioItem.new(value: :b)) { "B" }
      end
    end
    doc = fragment(html)
    a, b = doc.css("[data-slot=dropdown-menu-radio-item]")

    assert_equal "group", doc.at_css("[data-slot=dropdown-menu-radio-group]")["role"]
    assert_equal %w[menuitemradio false unchecked], [ a["role"], a["aria-checked"], a["data-state"] ]
    assert_equal %w[true checked], [ b["aria-checked"], b["data-state"] ]
    assert b.at_css("span[data-state=checked] svg.lucide-circle")
    assert_nil a.at_css("svg")
  end

  test "label, separator, shortcut and group" do
    html = menu do
      render(DropdownMenu::Label.new(inset: true)) { "L" }
      render DropdownMenu::Separator.new
      render(DropdownMenu::Group.new) { render(DropdownMenu::Item.new) { "I" } }
      render(DropdownMenu::Item.new) { render(DropdownMenu::Shortcut.new(class: "x")) { "K" } }
    end
    doc = fragment(html)

    assert_equal "true", doc.at_css("[data-slot=dropdown-menu-label]")["data-inset"]
    separator = doc.at_css("[data-slot=dropdown-menu-separator]")

    assert_equal %w[separator horizontal], [ separator["role"], separator["aria-orientation"] ]
    assert_equal "span", doc.at_css("[data-slot=dropdown-menu-shortcut]").name
    assert_includes doc.at_css("[data-slot=dropdown-menu-shortcut]")["class"].split, "x"
    assert_equal "group", doc.at_css("[data-slot=dropdown-menu-group]")["role"]
  end

  test "sub menu wires trigger and content ids and carries its own template" do
    html = menu do
      render DropdownMenu::Sub.new(default_open: true) do
        render(DropdownMenu::SubTrigger.new(inset: true)) { "More" }
        render DropdownMenu::Portal.new do
          render(DropdownMenu::SubContent.new(align_offset: 3)) { render(DropdownMenu::Item.new) { "Deep" } }
        end
      end
    end
    doc = fragment(html)
    trigger = doc.at_css("[data-slot=dropdown-menu-sub-trigger]")
    template = doc.at_css("template[data-shadcn--dropdown-menu-template$='-sub-2-content'], template[data-shadcn--dropdown-menu-template*='-sub-']")
    content = template.at_css("[data-slot=dropdown-menu-sub-content]")

    assert_equal %w[true open true], [ trigger["aria-expanded"], trigger["data-state"], trigger["data-inset"] ]
    assert_equal content["id"], trigger["aria-controls"]
    assert_equal trigger["id"], content["aria-labelledby"]
    assert trigger.at_css("svg.lucide-chevron-right")
    assert JSON.parse(template["data-options"])["portal"]
    assert_equal 3, JSON.parse(template["data-options"])["alignOffset"]
  end

  test "string and symbol options are equivalent" do
    options = ->(**o) { fragment(menu(content: o)).at_css("template")["data-options"] }

    assert_equal options.call(side: :top, align: :end, sticky: :always), options.call(side: "top", align: "end", sticky: "always")
  end

  test "helpers on the yielded root render the same HTML as the explicit classes" do
    explicit = render_view do
      render(DropdownMenu.new) do
        render(DropdownMenu::Trigger.new) { "Open" }
        render(DropdownMenu::Content.new) do
          render(DropdownMenu::Label.new) { "L" }
          render(DropdownMenu::Item.new(variant: :destructive)) { "I" }
          render(DropdownMenu::Sub.new) do
            render(DropdownMenu::SubTrigger.new) { "S" }
            render(DropdownMenu::SubContent.new) { render(DropdownMenu::Separator.new) }
          end
        end
      end
    end
    helpers = render_view do
      render(DropdownMenu.new) do |menu|
        menu.trigger { "Open" }
        menu.content do
          menu.label { "L" }
          menu.item(variant: :destructive) { "I" }
          menu.sub do
            menu.sub_trigger { "S" }
            menu.sub_content { menu.separator }
          end
        end
      end
    end

    assert_equal explicit, helpers
  end

  test "every part has a generated helper on the root" do
    HELPERS.each_key { |helper| assert_includes DropdownMenu.public_instance_methods(false), helper }
    HELPERS.each do |helper, klass|
      args = klass == DropdownMenu::RadioItem ? { value: "v" } : {}
      explicit = render_view do
        render(DropdownMenu.new) { render(DropdownMenu::Sub.new) { render(klass.new(**args)) { "x" } } }
      end
      via_helper = render_view do
        render(DropdownMenu.new) { |menu| menu.sub { menu.public_send(helper, **args) { "x" } } }
      end

      assert_equal explicit, via_helper, helper.to_s
    end
  end

  test "dir resolves from the direction provider and a local dir wins" do
    provided = render_view { render(Phlex::Shadcn::Direction::Provider.new(dir: "rtl")) { render(DropdownMenu.new) { render(DropdownMenu::Trigger.new) { "x" } } } }
    local = render_view { render(Phlex::Shadcn::Direction::Provider.new(dir: "rtl")) { render(DropdownMenu.new(dir: "ltr")) { render(DropdownMenu::Trigger.new) { "x" } } } }

    assert_includes provided, "rtl"
    assert_not_includes local, "rtl"
  end
end

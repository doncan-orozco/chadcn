# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::DropdownMenuTest < Chadcn::TestCase
  DropdownMenu = Chadcn::DropdownMenu

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
    assert_equal "chadcn--dropdown-menu", trigger["data-controller"]

    template = doc.at_css("template[data-chadcn--dropdown-menu-template]")
    content = template.at_css("[data-slot=dropdown-menu-content]")

    assert_equal "menu", content["role"]
    assert_equal "vertical", content["aria-orientation"]
    assert_equal trigger["id"], content["aria-labelledby"]
    assert_includes content["style"], "--radix-dropdown-menu-content-available-height: var(--radix-popper-available-height)"
    assert_includes content["class"], "min-w-[8rem]"
    contents = doc.css("[data-slot=dropdown-menu-content]")

    assert_equal 1, contents.size
    assert_predicate contents.first.ancestors("template"), :any?, "content must only exist inside the inert template"
  end

  test "open menu mirrors the open state on the trigger" do
    trigger = fragment(menu(root: { default_open: true })).at_css("[data-slot=dropdown-menu-trigger]")

    assert_equal "true", trigger["aria-expanded"]
    assert_equal "open", trigger["data-state"]
    assert trigger["aria-controls"]
    assert_equal "true", trigger["data-chadcn--dropdown-menu-open-value"]
    assert_equal "false", trigger["data-chadcn--dropdown-menu-controlled-value"]
  end

  test "controlled root wins over default_open and is flagged" do
    trigger = fragment(menu(root: { open: false, default_open: true })).at_css("[data-slot=dropdown-menu-trigger]")

    assert_equal "closed", trigger["data-state"]
    assert_equal "true", trigger["data-chadcn--dropdown-menu-controlled-value"]
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
    template = doc.at_css("template[data-chadcn--dropdown-menu-template$='-sub-2-content'], template[data-chadcn--dropdown-menu-template*='-sub-']")
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
    provided = render_view { render(Chadcn::Direction::Provider.new(dir: "rtl")) { render(DropdownMenu.new) { render(DropdownMenu::Trigger.new) { "x" } } } }
    local = render_view { render(Chadcn::Direction::Provider.new(dir: "rtl")) { render(DropdownMenu.new(dir: "ltr")) { render(DropdownMenu::Trigger.new) { "x" } } } }

    assert_equal "rtl", fragment(provided).at_css("[data-slot=dropdown-menu-trigger]")["data-chadcn--dropdown-menu-dir-value"]
    assert_equal "ltr", fragment(local).at_css("[data-slot=dropdown-menu-trigger]")["data-chadcn--dropdown-menu-dir-value"]
  end

  test "content serializes the positioning options into the template with the documented defaults" do
    options = JSON.parse(fragment(menu).at_css("template")["data-options"])

    assert_equal(
      { "side" => "bottom", "sideOffset" => 4, "align" => "center", "alignOffset" => 0, "avoidCollisions" => true,
        "collisionPadding" => 0, "arrowPadding" => 0, "sticky" => "partial", "hideWhenDetached" => false,
        "updatePositionStrategy" => "optimized", "loop" => false, "forceMount" => false },
      options
    )
  end

  test "content options reflect the given keywords and keep collision_boundary only when set" do
    custom = menu(content: { side: :left, side_offset: 9, loop: true, force_mount: true, collision_boundary: "#main" })
    options = JSON.parse(fragment(custom).at_css("template")["data-options"])

    assert_equal [ "left", 9, true, true, "#main" ], options.values_at("side", "sideOffset", "loop", "forceMount", "collisionBoundary")
  end

  test "content class merges over the defaults, style is appended and as_child renders the given tag inside the template" do
    html = menu(content: { class: "min-w-56", style: "color: red", as_child: :section, data: { testid: "c" } })
    content = fragment(html).at_css("template > section")

    assert_equal "dropdown-menu-content", content["data-slot"]
    assert_equal "c", content["data-testid"]
    assert_includes content["class"].split, "min-w-56"
    assert_not_includes content["class"].split, "min-w-[8rem]"
    assert content["style"].start_with?("outline: none; color: red; ")
  end

  test "trigger, content, sub and sub content raise ArgumentError at render when used outside a DropdownMenu" do
    [ DropdownMenu::Trigger, DropdownMenu::Content, DropdownMenu::Sub, DropdownMenu::SubContent ].each do |klass|
      error = assert_raises(ArgumentError, klass.name) { render_view { render(klass.new) } }

      assert_equal "#{klass.name} must be used within DropdownMenu", error.message
    end
  end

  test "sub trigger and sub content raise ArgumentError at render when used outside a Sub but construct fine" do
    [ DropdownMenu::SubTrigger, DropdownMenu::SubContent ].each do |klass|
      part = klass.new
      error = assert_raises(ArgumentError, klass.name) { render_view { render(DropdownMenu.new) { render(part) } } }

      assert_equal "#{klass.name} must be used within DropdownMenu::Sub", error.message
    end
  end

  test "radio item without value raises at construction and an unknown keyword on Item becomes an attribute while the root raises" do
    assert_raises(ArgumentError) { DropdownMenu::RadioItem.new }
    assert_raises(ArgumentError) { DropdownMenu.new(unknown: 1) }

    item = fragment(menu { render(DropdownMenu::Item.new(title: "t")) { "x" } }).at_css("[data-slot=dropdown-menu-item]")

    assert_equal "t", item["title"]
  end

  test "radio item outside a group and in a group without value is unchecked" do
    outside = fragment(menu { render(DropdownMenu::RadioItem.new(value: "a")) { "A" } }).at_css("[data-slot=dropdown-menu-radio-item]")
    html = menu { render(DropdownMenu::RadioGroup.new) { render(DropdownMenu::RadioItem.new(value: "a")) { "A" } } }
    empty = fragment(html).at_css("[data-slot=dropdown-menu-radio-item]")

    assert_equal %w[false unchecked a], [ outside["aria-checked"], outside["data-state"], outside["data-chadcn--dropdown-menu-value"] ]
    assert_equal %w[false unchecked], [ empty["aria-checked"], empty["data-state"] ]
  end

  test "checkbox item accepts the indeterminate symbol and disabled, text_value and class merge" do
    html = menu { render(DropdownMenu::CheckboxItem.new(checked: :indeterminate, disabled: true, text_value: "Mix", class: "pl-2")) { "M" } }
    item = fragment(html).at_css("[data-slot=dropdown-menu-checkbox-item]")

    assert_equal %w[mixed indeterminate true Mix], [ item["aria-checked"], item["data-state"], item["aria-disabled"], item["data-text-value"] ]
    assert item.key?("data-disabled")
    assert_includes item["class"].split, "pl-2"
    assert_not_includes item["class"].split, "pl-8"
  end

  test "group, label, separator and radio group render as_child with the given tag and keep passthrough attrs" do
    html = menu do
      render(DropdownMenu::Group.new(as_child: :ul, id: "g")) { "g" }
      render(DropdownMenu::Label.new(as_child: :h3, class: "px-4")) { "l" }
      render DropdownMenu::Separator.new(as_child: :hr, id: "s")
      render(DropdownMenu::RadioGroup.new(value: "a", as_child: :ol)) { "r" }
    end
    doc = fragment(html)

    assert_equal "g", doc.at_css("ul[data-slot=dropdown-menu-group]")["id"]
    assert_includes doc.at_css("h3[data-slot=dropdown-menu-label]")["class"].split, "px-4"
    assert_equal "separator", doc.at_css("hr[data-slot=dropdown-menu-separator]")["role"]
    assert_equal "group", doc.at_css("ol[data-slot=dropdown-menu-radio-group]")["role"]
  end

  test "item as_child accepts a component instance and merges the item attributes into it" do
    html = menu { render(DropdownMenu::Item.new(as_child: Chadcn::Button.new(href: "/x"))) { "Go" } }
    item = fragment(html).at_css("[data-slot=dropdown-menu-item]")

    assert_equal "menuitem", item["role"]
    assert_equal "default", item["data-variant"]
  end

  test "each part renders exactly its CLASSES table on its data-slot element" do
    tables = {
      DropdownMenu::Content => "dropdown-menu-content", DropdownMenu::SubContent => "dropdown-menu-sub-content",
      DropdownMenu::Item => "dropdown-menu-item", DropdownMenu::CheckboxItem => "dropdown-menu-checkbox-item",
      DropdownMenu::RadioItem => "dropdown-menu-radio-item", DropdownMenu::Label => "dropdown-menu-label",
      DropdownMenu::Separator => "dropdown-menu-separator", DropdownMenu::Shortcut => "dropdown-menu-shortcut",
      DropdownMenu::SubTrigger => "dropdown-menu-sub-trigger"
    }
    html = menu(root: { default_open: true }) do
      render(DropdownMenu::Label.new) { "l" }
      render(DropdownMenu::Item.new) { render(DropdownMenu::Shortcut.new) { "k" } }
      render(DropdownMenu::CheckboxItem.new) { "c" }
      render(DropdownMenu::RadioItem.new(value: "a")) { "r" }
      render(DropdownMenu::Separator.new)
      render(DropdownMenu::Sub.new) do
        render(DropdownMenu::SubTrigger.new) { "s" }
        render(DropdownMenu::SubContent.new) { "x" }
      end
    end
    doc = fragment(html)

    tables.each do |klass, slot|
      assert_kind_of String, klass::CLASSES, klass.name
      assert_equal klass::CLASSES.split.sort, doc.at_css("[data-slot=#{slot}]")["class"].split.sort, slot
    end
    assert_equal DropdownMenu::CheckboxItem::INDICATOR_CLASSES, doc.at_css("[data-slot=dropdown-menu-checkbox-item] > span")["class"]
    assert_equal DropdownMenu::RadioItem::INDICATOR_CLASSES, doc.at_css("[data-slot=dropdown-menu-radio-item] > span")["class"]
  end

  test "an unknown dir falls back to ltr without raising" do
    html = render_view { render(DropdownMenu.new(dir: "sideways")) { render(DropdownMenu::Trigger.new) { "x" } } }

    assert_equal "ltr", fragment(html).at_css("button")["data-chadcn--dropdown-menu-dir-value"]
  end

  test "modal false and dir rtl reach the trigger values and the content" do
    html = menu(root: { modal: false, dir: "rtl" })
    doc = fragment(html)
    trigger = doc.at_css("button")

    assert_equal "false", trigger["data-chadcn--dropdown-menu-modal-value"]
    assert_equal "rtl", trigger["data-chadcn--dropdown-menu-dir-value"]
    assert_equal "rtl", doc.at_css("[data-slot=dropdown-menu-content]")["dir"]
  end

  test "ids are unique per menu in one render and the trigger points at its own content template" do
    html = render_view do
      render(DropdownMenu.new) do
        render(DropdownMenu::Trigger.new) { "a" }
        render(DropdownMenu::Content.new) { "x" }
      end
      render(DropdownMenu.new) { render(DropdownMenu::Trigger.new) { "b" } }
    end
    doc = fragment(html)
    first, second = doc.css("button")

    assert_equal first["data-chadcn--dropdown-menu-template-value"], doc.at_css("template")["data-chadcn--dropdown-menu-template"]

    assert_not_equal first["id"], second["id"]
    assert_not_equal first["data-chadcn--dropdown-menu-template-value"], second["data-chadcn--dropdown-menu-template-value"]
  end

  test "controlled sub menu is flagged on its trigger and open reflects on aria-controls" do
    html = menu do
      render DropdownMenu::Sub.new(open: false, default_open: true) do
        render(DropdownMenu::SubTrigger.new(disabled: true, text_value: "More")) { "More" }
      end
    end
    trigger = fragment(html).at_css("[data-slot=dropdown-menu-sub-trigger]")

    assert_equal %w[true closed false], [ trigger["data-chadcn--dropdown-menu-sub-controlled"], trigger["data-state"], trigger["aria-expanded"] ]
    assert_nil trigger["aria-controls"]
    assert trigger.key?("data-disabled")
    assert_equal "More", trigger["data-text-value"]
  end

  test "portal container and force_mount reach only the sub content inside it" do
    html = menu do
      render DropdownMenu::Sub.new do
        render(DropdownMenu::SubTrigger.new) { "A" }
        render(DropdownMenu::Portal.new(container: "#modal", force_mount: true)) do
          render(DropdownMenu::SubContent.new) do
            render DropdownMenu::Sub.new do
              render(DropdownMenu::SubTrigger.new) { "B" }
              render(DropdownMenu::SubContent.new) { "inner" }
            end
          end
        end
      end
    end
    templates = fragment(html).css("template[data-chadcn--dropdown-menu-template*='-sub-']")
    outer = JSON.parse(templates.first["data-options"])
    inner = JSON.parse(templates.last["data-options"])

    assert_equal [ "#modal", true, true ], outer.values_at("container", "forceMount", "portal")
    assert_equal [ false, false ], [ inner.key?("container"), inner["portal"] ]
    refute inner["forceMount"]
  end

  test "sub content options hold no side key and carry the sub defaults for align and side_offset" do
    options = JSON.parse(fragment(menu { render(DropdownMenu::Sub.new) { render(DropdownMenu::SubContent.new) { "x" } } }).at_css("template template, template[data-chadcn--dropdown-menu-template*='-sub-']")["data-options"])

    assert_not options.key?("side")
    assert_equal [ "start", 0 ], options.values_at("align", "sideOffset")
  end

  test "shortcut passes attrs and as_child is just a plain attribute" do
    html = menu { render(DropdownMenu::Item.new) { render(DropdownMenu::Shortcut.new(title: "t", as_child: :a)) { "K" } } }
    shortcut = fragment(html).at_css("[data-slot=dropdown-menu-shortcut]")

    assert_equal "t", shortcut["title"]
    assert_equal "K", shortcut.text
    assert_nil shortcut.at_css("a")
  end

  test "id names the content; the trigger and the subs derive their ids from it" do
    doc = fragment(menu(root: { id: "row-actions", default_open: true }) do
      render(DropdownMenu::Sub.new) do
        render(DropdownMenu::SubTrigger.new) { "More" }
        render(DropdownMenu::SubContent.new) { render(DropdownMenu::Item.new) { "Export" } }
      end
    end)
    trigger = doc.at_css("[data-slot=dropdown-menu-trigger]")
    content = doc.at_css("[data-slot=dropdown-menu-content]")

    assert_equal "row-actions-trigger", trigger["id"]
    assert_equal "row-actions", trigger["aria-controls"]
    assert_equal "row-actions", content["id"]
    assert_equal "row-actions-trigger", content["aria-labelledby"]
    assert_equal "row-actions-sub-1-trigger", doc.at_css("[data-slot=dropdown-menu-sub-trigger]")["id"]
    assert_equal "row-actions-sub-1", doc.at_css("[data-slot=dropdown-menu-sub-content]")["id"]
  end

  test "roots without id are numbered per render" do
    html = render_view { 2.times { render(DropdownMenu.new) { render(DropdownMenu::Trigger.new) { "x" } } } }

    assert_equal(%w[dropdown-menu-1-trigger dropdown-menu-2-trigger],
                 fragment(html).css("[data-slot=dropdown-menu-trigger]").map { |trigger| trigger["id"] })
  end
end

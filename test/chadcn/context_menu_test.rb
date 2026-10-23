# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::ContextMenuTest < Chadcn::TestCase
  ContextMenu = Chadcn::ContextMenu

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

  test "group, label, separator and radio group render as_child with the given tag" do
    html = menu do
      render(ContextMenu::Group.new(as_child: :ul, id: "g")) { "g" }
      render(ContextMenu::Label.new(as_child: :h3, class: "px-4")) { "l" }
      render ContextMenu::Separator.new(as_child: :hr, id: "s")
      render(ContextMenu::RadioGroup.new(value: "a", as_child: :ol)) { "r" }
    end
    doc = fragment(html)

    assert_equal "g", doc.at_css("ul[data-slot=context-menu-group]")["id"]
    assert_includes doc.at_css("h3[data-slot=context-menu-label]")["class"].split, "px-4"
    assert_equal "s", doc.at_css("hr[data-slot=context-menu-separator]")["id"]
    assert_equal "group", doc.at_css("ol[data-slot=context-menu-radio-group]")["role"]
  end

  test "dir resolves from the direction provider and a local dir wins" do
    provider = Chadcn::Direction::Provider
    provided = render_view { render(provider.new(dir: "rtl")) { render(ContextMenu.new) { render(ContextMenu::Trigger.new) { "x" } } } }
    local = render_view { render(provider.new(dir: "rtl")) { render(ContextMenu.new(dir: "ltr")) { render(ContextMenu::Trigger.new) { "x" } } } }

    assert_equal "rtl", fragment(provided).at_css("[data-slot=context-menu-trigger]")["data-chadcn--context-menu-dir-value"]
    assert_equal "ltr", fragment(local).at_css("[data-slot=context-menu-trigger]")["data-chadcn--context-menu-dir-value"]
  end

  test "trigger is a bare span hosting the controller" do
    trigger = fragment(menu).at_css("[data-slot=context-menu-trigger]")

    assert_equal "span", trigger.name
    assert_equal "closed", trigger["data-state"]
    assert_equal "chadcn--context-menu", trigger["data-controller"]
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
    template = fragment(menu(content: { class: "w-64" })).at_css("template[data-chadcn--dropdown-menu-template]")
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
    assert_equal "true", trigger["data-chadcn--context-menu-controlled-value"]
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

  def render_in_menu(&block)
    render_view { render(ContextMenu.new) { instance_exec(&block) } }
  end

  test "every default class table is applied by its part" do
    merger = Chadcn::Base.tw_merger
    {
      ContextMenu::Item => "[data-slot=context-menu-item]",
      ContextMenu::CheckboxItem => "[data-slot=context-menu-checkbox-item]",
      ContextMenu::RadioItem => "[data-slot=context-menu-radio-item]",
      ContextMenu::Label => "[data-slot=context-menu-label]",
      ContextMenu::Separator => "[data-slot=context-menu-separator]",
      ContextMenu::Shortcut => "[data-slot=context-menu-shortcut]"
    }.each do |part, selector|
      args = part == ContextMenu::RadioItem ? { value: "a" } : {}
      node = fragment(render_in_menu { render(part.new(**args)) { "x" } }).at_css(selector)

      assert_equal merger.merge(part::CLASSES), node["class"], part.name
    end
    {
      ContextMenu::Content => "[data-slot=context-menu-content]", ContextMenu::SubContent => "[data-slot=context-menu-sub-content]"
    }.each do |part, selector|
      html = render_in_menu { render(ContextMenu::Sub.new) { render(part.new) { "x" } } }

      assert_equal merger.merge(part::CLASSES), fragment(html).at_css(selector)["class"], part.name
    end
    html = render_in_menu { render(ContextMenu::Sub.new) { render(ContextMenu::SubTrigger.new) { "x" } } }

    assert_equal merger.merge(ContextMenu::SubTrigger::CLASSES), fragment(html).at_css("[data-slot=context-menu-sub-trigger]")["class"]
  end

  test "indicator classes are applied to the checkbox and radio indicators" do
    html = render_in_menu do
      render(ContextMenu::CheckboxItem.new) { "x" }
      render(ContextMenu::RadioItem.new(value: "a")) { "y" }
    end
    doc = fragment(html)

    assert_equal ContextMenu::CheckboxItem::INDICATOR_CLASSES, doc.at_css("[data-slot=context-menu-checkbox-item] > span")["class"]
    assert_equal ContextMenu::RadioItem::INDICATOR_CLASSES, doc.at_css("[data-slot=context-menu-radio-item] > span")["class"]
  end

  test "content style maps every context menu popper variable to its popper source" do
    style = fragment(menu).at_css("[data-slot=context-menu-content]")["style"]

    %w[content-available-height content-available-width content-transform-origin trigger-height trigger-width].each do |name|
      assert_match(/--radix-context-menu-#{name}: var\(--radix-popper-[a-z-]+\)/, style, name)
    end
    assert_includes style, "--radix-context-menu-content-transform-origin: var(--radix-popper-transform-origin)"
  end

  test "parts that do not read the root render without a ContextMenu" do
    html = render_view do
      render(ContextMenu::Group.new) { render(ContextMenu::Label.new) { "People" } }
      render(ContextMenu::Item.new) { "Back" }
      render(ContextMenu::Separator.new)
      render(ContextMenu::Shortcut.new) { "Cmd+[" }
      render(ContextMenu::RadioGroup.new(value: "a")) { render(ContextMenu::RadioItem.new(value: "a")) { "A" } }
      render(ContextMenu::Portal.new) { plain "inside" }
    end
    doc = fragment(html)

    assert_equal "Back", doc.at_css("[data-slot=context-menu-item]").text
    assert_equal "People", doc.at_css("[data-slot=context-menu-label]").text
    assert doc.at_css("[data-slot=context-menu-separator]")
    assert_equal "Cmd+[", doc.at_css("[data-slot=context-menu-shortcut]").text
    assert_equal "checked", doc.at_css("[data-slot=context-menu-radio-item]")["data-state"]
    assert_includes html, "inside"
  end

  test "root passes dir and modal to the trigger values and the content" do
    doc = fragment(menu(root: { dir: "rtl", modal: false }))
    trigger = doc.at_css("[data-slot=context-menu-trigger]")

    assert_equal "rtl", trigger["data-chadcn--context-menu-dir-value"]
    assert_equal "false", trigger["data-chadcn--context-menu-modal-value"]
    assert_equal "rtl", doc.at_css("[data-slot=context-menu-content]")["dir"]
  end

  test "root ignores a dir that is not ltr or rtl and falls back to ltr" do
    trigger = fragment(menu(root: { dir: "auto" })).at_css("[data-slot=context-menu-trigger]")

    assert_equal "ltr", trigger["data-chadcn--context-menu-dir-value"]
    assert_equal "true", trigger["data-chadcn--context-menu-modal-value"]
  end

  test "controlled root false renders closed and marks the trigger controlled" do
    trigger = fragment(menu(root: { open: false })).at_css("[data-slot=context-menu-trigger]")

    assert_equal "closed", trigger["data-state"]
    assert_equal "true", trigger["data-chadcn--context-menu-controlled-value"]
    assert_equal "false", trigger["data-chadcn--context-menu-open-value"]
  end

  test "ids are unique per menu within one render" do
    html = render_view do
      2.times { render(ContextMenu.new) { render(ContextMenu::Trigger.new) { "x" } } }
    end
    values = fragment(html).css("[data-slot=context-menu-trigger]").map { |el| el["data-chadcn--context-menu-template-value"] }

    assert_equal %w[context-menu-1 context-menu-2], values
  end

  test "trigger as_child with a tag symbol renders that element with the controller attributes" do
    html = render_in_menu { render(ContextMenu::Trigger.new(as_child: :a, href: "/x", class: "p-1")) { "x" } }
    trigger = fragment(html).at_css("[data-slot=context-menu-trigger]")

    assert_equal "a", trigger.name
    assert_equal "/x", trigger["href"]
    assert_equal "chadcn--context-menu", trigger["data-controller"]
    assert_equal "p-1", trigger["class"]
  end

  test "as_child with a component instance merges the part attributes into it" do
    html = render_in_menu { render(ContextMenu::Item.new(as_child: Chadcn::Button.new(variant: "ghost"))) { "x" } }
    item = fragment(html).at_css("[data-slot=context-menu-item]")

    assert_equal "button", item.name
    assert_equal "menuitem", item["role"]
    assert_equal "-1", item["tabindex"]
  end

  test "item merges the caller class over the defaults with tailwind-merge" do
    item = fragment(menu { render(ContextMenu::Item.new(class: "px-4", data: { foo: "bar" })) { "x" } }).at_css("[data-slot=context-menu-item]")
    classes = item["class"].split

    assert_includes classes, "px-4"
    assert_not_includes classes, "px-2"
    assert_equal "bar", item["data-foo"]
    assert_equal "-1", item["tabindex"]
  end

  test "item omits data-inset when inset is nil, renders false and applies text_value" do
    doc = fragment(menu do
      render(ContextMenu::Item.new) { "a" }
      render(ContextMenu::Item.new(inset: false, text_value: "Bee")) { "b" }
    end)
    plain, inset = doc.css("[data-slot=context-menu-item]")

    assert_not plain.key?("data-inset")
    assert_equal "default", plain["data-variant"]
    assert_equal "false", inset["data-inset"]
    assert_equal "Bee", inset["data-text-value"]
  end

  test "checkbox item renders checked, unchecked and disabled states" do
    doc = fragment(menu do
      render(ContextMenu::CheckboxItem.new(checked: true)) { "a" }
      render(ContextMenu::CheckboxItem.new(disabled: true)) { "b" }
    end)
    checked, unchecked = doc.css("[data-slot=context-menu-checkbox-item]")

    assert_equal "true", checked["aria-checked"]
    assert_equal "checked", checked["data-state"]
    assert checked.at_css("svg.lucide-check")
    assert_equal "false", unchecked["aria-checked"]
    assert_equal "unchecked", unchecked["data-state"]
    assert_nil unchecked.at_css("svg")
    assert_equal "true", unchecked["aria-disabled"]
    assert unchecked.key?("data-disabled")
  end

  test "radio item is never checked outside a radio group and requires value" do
    item = fragment(menu { render(ContextMenu::RadioItem.new(value: :a)) { "x" } }).at_css("[data-slot=context-menu-radio-item]")

    assert_equal "false", item["aria-checked"]
    assert_equal "a", item["data-chadcn--dropdown-menu-value"]
    assert_raises(ArgumentError) { ContextMenu::RadioItem.new }
  end

  test "radio group compares values as strings and shows the circle on the checked item" do
    doc = fragment(menu do
      render(ContextMenu::RadioGroup.new(value: 2)) do
        render(ContextMenu::RadioItem.new(value: "1")) { "one" }
        render(ContextMenu::RadioItem.new(value: 2)) { "two" }
      end
    end)
    one, two = doc.css("[data-slot=context-menu-radio-item]")

    assert_nil one.at_css("svg")
    assert_equal "checked", two["data-state"]
    assert two.at_css("svg.lucide-circle")
  end

  test "group, label, separator and shortcut render their roles and slots" do
    doc = fragment(menu do
      render(ContextMenu::Group.new(class: "a b")) do
        render(ContextMenu::Label.new(inset: true)) { "L" }
        render(ContextMenu::Separator.new)
        render(ContextMenu::Shortcut.new(class: "x")) { "S" }
      end
    end)

    assert_equal "group", doc.at_css("[data-slot=context-menu-group]")["role"]
    assert_equal "a b", doc.at_css("[data-slot=context-menu-group]")["class"]
    assert_equal "true", doc.at_css("[data-slot=context-menu-label]")["data-inset"]
    separator = doc.at_css("[data-slot=context-menu-separator]")

    assert_equal "separator", separator["role"]
    assert_equal "horizontal", separator["aria-orientation"]
    shortcut = doc.at_css("[data-slot=context-menu-shortcut]")

    assert_equal "span", shortcut.name
    assert_includes shortcut["class"].split, "x"
    assert_equal "S", shortcut.text
  end

  test "content serializes the default and custom positioning options" do
    default = JSON.parse(fragment(menu).at_css("template")["data-options"])
    custom = JSON.parse(fragment(menu(content: { loop: true, align_offset: 4, collision_boundary: [ ".a" ], force_mount: true }))
                          .at_css("template")["data-options"])

    assert_equal({ "alignOffset" => 0, "avoidCollisions" => true, "collisionPadding" => 0, "arrowPadding" => 0, "sticky" => "partial",
                   "hideWhenDetached" => false, "updatePositionStrategy" => "optimized", "loop" => false, "forceMount" => false },
                 default.except("side", "sideOffset", "align"))
    assert_not default.key?("collisionBoundary")
    assert_equal [ true, 4, [ ".a" ], true ], custom.values_at("loop", "alignOffset", "collisionBoundary", "forceMount")
  end

  test "content appends the caller style after the default outline" do
    content = fragment(menu(content: { style: "width: 10px" })).at_css("[data-slot=context-menu-content]")

    assert_match(/\Aoutline: none; width: 10px; --radix-context-menu-content-transform-origin/, content["style"])
  end

  test "content rejects forced options with the offending keyword names at construction" do
    error = assert_raises(ArgumentError) { ContextMenu::Content.new(side: "left", align: "end") }

    assert_equal "unknown keywords: :side, :align", error.message
    assert_equal "unknown keyword: :side_offset", assert_raises(ArgumentError) { ContextMenu::Content.new(side_offset: 1) }.message
  end

  test "parts raise ArgumentError at render time, not construction, outside a context menu" do
    [ ContextMenu::Trigger, ContextMenu::Content, ContextMenu::Sub, ContextMenu::SubContent ].each do |part|
      instance = part.new
      error = assert_raises(ArgumentError, part.name) { render_view { render(instance) { "x" } } }

      assert_equal "#{part.name} must be used within ContextMenu", error.message
    end
  end

  test "sub trigger and sub content raise when rendered outside a sub" do
    %w[SubTrigger SubContent].each do |name|
      error = assert_raises(ArgumentError, name) { render_in_menu { render(ContextMenu.const_get(name).new) { "x" } } }

      assert_equal "Chadcn::ContextMenu::#{name} must be used within ContextMenu::Sub", error.message
    end
  end

  test "portal renders no element and works without a root" do
    html = render_view { render(ContextMenu::Portal.new) { plain "inside" } }

    assert_equal "inside", html
  end

  test "sub controlled open marks the trigger open and wires the content id" do
    html = render_in_menu do
      render(ContextMenu::Sub.new(open: true)) do
        render(ContextMenu::SubTrigger.new(inset: true, disabled: true)) { "More" }
        render(ContextMenu::SubContent.new) { "x" }
      end
    end
    doc = fragment(html)
    trigger = doc.at_css("[data-slot=context-menu-sub-trigger]")
    content = doc.at_css("[data-slot=context-menu-sub-content]")

    assert_equal "open", trigger["data-state"]
    assert_equal "true", trigger["aria-expanded"]
    assert_equal content["id"], trigger["aria-controls"]
    assert_equal "true", trigger["data-chadcn--dropdown-menu-sub-controlled"]
    assert_equal "true", trigger["data-inset"]
    assert_equal "true", trigger["aria-disabled"]
    assert trigger.at_css("svg.lucide-chevron-right")
  end

  test "sub default_open renders the uncontrolled sub trigger open in the server markup" do
    html = render_in_menu do
      render(ContextMenu::Sub.new(default_open: true)) { render(ContextMenu::SubTrigger.new) { "More" } }
    end
    trigger = fragment(html).at_css("[data-slot=context-menu-sub-trigger]")

    assert_equal "open", trigger["data-state"]
    assert_equal "false", trigger["data-chadcn--dropdown-menu-sub-controlled"]
  end

  test "sub content follows the root direction and serializes its options" do
    html = render_view do
      render(ContextMenu.new(dir: "rtl")) { render(ContextMenu::Sub.new) { render(ContextMenu::SubContent.new(align: :end, loop: true)) { "x" } } }
    end
    doc = fragment(html)
    options = JSON.parse(doc.at_css("template")["data-options"])

    assert_equal "rtl", doc.at_css("[data-slot=context-menu-sub-content]")["dir"]
    assert_equal({ "sideOffset" => 0, "align" => "end", "loop" => true, "forceMount" => false, "portal" => false },
                 options.slice("sideOffset", "align", "loop", "forceMount", "portal"))
  end

  test "portal moves its sub content to the container and does not reach nested sub menus" do
    html = render_in_menu do
      render(ContextMenu::Sub.new) do
        render(ContextMenu::Portal.new(force_mount: true, container: "#overlays")) do
          render(ContextMenu::SubContent.new) { render(ContextMenu::Sub.new) { render(ContextMenu::SubContent.new) { "inner" } } }
        end
      end
    end
    outer, inner = fragment(html).css("template").map { |el| JSON.parse(el["data-options"]) }

    assert_equal [ true, "#overlays", true ], outer.values_at("portal", "container", "forceMount")
    assert_equal [ false, false ], inner.values_at("portal", "forceMount")
    assert_not inner.key?("container")
  end

  test "sub content force_mount works without a portal" do
    html = render_in_menu { render(ContextMenu::Sub.new) { render(ContextMenu::SubContent.new(force_mount: true)) { "x" } } }

    assert JSON.parse(fragment(html).at_css("template")["data-options"])["forceMount"]
  end

  test "generated DX helpers pass attributes through to the part" do
    html = render_view do
      render(ContextMenu.new) do |root|
        root.trigger(class: "t-1") { "x" }
        root.content(class: "c-1") { root.item(variant: :destructive) { "y" } }
      end
    end
    doc = fragment(html)

    assert_includes doc.at_css("[data-slot=context-menu-trigger]")["class"], "t-1"
    assert_includes doc.at_css("[data-slot=context-menu-content]")["class"].split, "c-1"
    assert_equal "destructive", doc.at_css("[data-slot=context-menu-item]")["data-variant"]
  end

  test "id names the content" do
    doc = fragment(menu(root: { id: "file-menu" }))

    assert_equal "file-menu", doc.at_css("[data-slot=context-menu-trigger]")["data-chadcn--context-menu-template-value"]
    assert_equal "file-menu", doc.at_css("[data-slot=context-menu-content]")["id"]
  end

  test "with id the subs are <id>-sub-N and the trigger, template key and content id of a sub agree" do
    doc = fragment(menu(root: { id: "cm" }) do
      render(ContextMenu::Sub.new) do
        render(ContextMenu::SubTrigger.new) { "More" }
        render(ContextMenu::SubContent.new) { render(ContextMenu::Item.new) { "Save" } }
      end
    end)
    trigger = doc.at_css("[data-slot=context-menu-sub-trigger]")
    template = doc.at_css("template[data-chadcn--dropdown-menu-template='cm-sub-1']")
    content = template.at_css("[data-slot=context-menu-sub-content]")

    assert_equal "cm-sub-1-trigger", trigger["id"]
    assert_equal "cm-sub-1", content["id"]
    assert_equal "cm-sub-1-trigger", content["aria-labelledby"]
    assert_equal "cm-sub-1", trigger["data-chadcn--dropdown-menu-sub-content-id"]
    assert_equal template["data-chadcn--dropdown-menu-template"], trigger["data-chadcn--dropdown-menu-sub-content-id"]
    assert_equal content["id"], trigger["data-chadcn--dropdown-menu-sub-content-id"]
  end
end

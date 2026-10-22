# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::MenubarTest < Chadcn::TestCase
  Menubar = Chadcn::Menubar

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

  test "dir resolves from the direction provider and a local dir wins" do
    provider = Chadcn::Direction::Provider
    provided = render_view { render(provider.new(dir: "rtl")) { render(Menubar.new) { "x" } } }
    local = render_view { render(provider.new(dir: "rtl")) { render(Menubar.new(dir: "ltr")) { "x" } } }

    assert_equal "rtl", fragment(provided).at_css("[data-slot=menubar]")["data-shadcn--menubar-dir-value"]
    assert_equal "ltr", fragment(local).at_css("[data-slot=menubar]")["data-shadcn--menubar-dir-value"]
  end

  test "constants expose the default class tables" do
    assert_includes Menubar::CLASSES, "h-9"
    assert_includes Menubar::Trigger::CLASSES, "data-[state=open]:bg-accent"
    assert_includes Menubar::Content::CLASSES, "min-w-[12rem]"
    assert_includes Menubar::SubContent::CLASSES, "min-w-[8rem]"
    assert_includes Menubar::Item::CLASSES, "data-[variant=destructive]:text-destructive"
    assert_includes Menubar::CheckboxItem::CLASSES, "pl-8"
    assert_includes Menubar::RadioItem::CLASSES, "pl-8"
    assert_includes Menubar::CheckboxItem::INDICATOR_CLASSES, "absolute"
    assert_includes Menubar::RadioItem::INDICATOR_CLASSES, "absolute"
    assert_includes Menubar::Label::CLASSES, "font-medium"
    assert_includes Menubar::Separator::CLASSES, "bg-border"
    assert_includes Menubar::Shortcut::CLASSES, "tracking-widest"
    assert_includes Menubar::SubTrigger::CLASSES, "data-[state=open]:bg-accent"
  end

  test "an unsupported dir is ignored and falls back to ltr, loop defaults to true and can be turned off" do
    root = fragment(bar(root: { dir: "up" })).at_css("[data-slot=menubar]")

    assert_equal "ltr", root["data-shadcn--menubar-dir-value"]
    assert_equal "true", root["data-shadcn--menubar-loop-value"]
    assert_equal "false", fragment(bar(root: { loop: false })).at_css("[data-slot=menubar]")["data-shadcn--menubar-loop-value"]
  end

  test "root uncontrolled by default and as_child renders the given element or a component instance" do
    root = fragment(bar).at_css("[data-slot=menubar]")

    assert_equal "div", root.name
    assert_equal "false", root["data-shadcn--menubar-controlled-value"]
    assert_equal "", root["data-shadcn--menubar-value-value"]

    as_nav = fragment(render_view { render(Menubar.new(as_child: :nav, class: "extra")) { "x" } }).at_css("[data-slot=menubar]")

    assert_equal "nav", as_nav.name
    assert_equal "menubar", as_nav["role"]
    assert_includes as_nav["class"], "extra"

    as_button = fragment(render_view { render(Menubar.new(as_child: Chadcn::Button.new(variant: "outline"))) { "x" } }).at_css("[data-slot=menubar]")

    assert_equal "button", as_button.name
    assert_equal "menubar", as_button["role"]
  end

  test "menu without value gets an auto value that the trigger exposes, an explicit value is used as is" do
    auto = fragment(render_view { render(Menubar.new) { render(Menubar::Menu.new) { render(Menubar::Trigger.new) { "T" } } } })
    value = auto.at_css("[data-slot=menubar-trigger]")["data-shadcn--menubar-menu-value"]

    assert_match(/\Amenubar-\d+-menu-\d+\z/, value)
    assert_equal "file", fragment(bar).at_css("[data-slot=menubar-trigger]")["data-shadcn--menubar-menu-value"]
  end

  test "parts raise ArgumentError at render, not at construction, when rendered outside their ancestor" do
    [ Menubar::Menu, Menubar::Trigger, Menubar::Content, Menubar::Sub, Menubar::SubTrigger, Menubar::SubContent ].each(&:new)

    assert_raises(ArgumentError) { render_view { render(Menubar::Menu.new) } }
    assert_raises(ArgumentError) { render_view { render(Menubar::Sub.new) } }
    assert_raises(ArgumentError) { render_view { render(Menubar.new) { render(Menubar::Trigger.new) { "x" } } } }
    assert_raises(ArgumentError) { render_view { render(Menubar.new) { render(Menubar::Content.new) } } }
    assert_raises(ArgumentError) { render_view { render(Menubar.new) { render(Menubar::SubTrigger.new) { "x" } } } }
    assert_raises(ArgumentError) { render_view { render(Menubar.new) { render(Menubar::SubContent.new) } } }
  end

  test "radio item requires a value at construction" do
    assert_raises(ArgumentError) { Menubar::RadioItem.new }
  end

  test "radio item outside a radio group renders unchecked" do
    item = fragment(bar { render(Menubar::RadioItem.new(value: "a")) { "A" } }).at_css("[data-slot=menubar-radio-item]")

    assert_equal "false", item["aria-checked"]
    assert_equal "unchecked", item["data-state"]
    assert_equal "a", item["data-shadcn--menubar-value"]
  end

  test "checkbox item states: checked, unchecked and the indicator" do
    doc = fragment(bar do
      render(Menubar::CheckboxItem.new(checked: true)) { "on" }
      render(Menubar::CheckboxItem.new) { "off" }
    end)
    on, off = doc.css("[data-slot=menubar-checkbox-item]")

    assert_equal %w[true checked], [ on["aria-checked"], on["data-state"] ]
    assert_equal %w[false unchecked], [ off["aria-checked"], off["data-state"] ]
    assert on.at_css("svg")
    assert_nil off.at_css("svg")
  end

  test "item text_value and disabled markers on item, checkbox, radio and sub trigger" do
    doc = fragment(bar do
      render(Menubar::Item.new(text_value: "Neu", disabled: true)) { "x" }
      render(Menubar::CheckboxItem.new(disabled: true)) { "x" }
      render(Menubar::RadioItem.new(value: "a", disabled: true)) { "x" }
      render(Menubar::Sub.new) { render(Menubar::SubTrigger.new(disabled: true, inset: true)) { "x" } }
    end)

    assert_equal "Neu", doc.at_css("[data-slot=menubar-item]")["data-text-value"]
    %w[menubar-item menubar-checkbox-item menubar-radio-item menubar-sub-trigger].each do |slot|
      el = doc.at_css("[data-slot=#{slot}]")

      assert_equal "", el["data-disabled"], slot
      assert_equal "true", el["aria-disabled"], slot
    end
    assert_equal "true", doc.at_css("[data-slot=menubar-sub-trigger]")["data-inset"]
  end

  test "group, label, separator and shortcut render their markup and merge classes" do
    doc = fragment(bar do
      render(Menubar::Group.new(class: "g-extra")) { render(Menubar::Label.new(inset: true, class: "l-extra")) { "L" } }
      render(Menubar::Separator.new(class: "s-extra"))
      render(Menubar::Item.new) { render(Menubar::Shortcut.new(class: "k-extra")) { "Ctrl" } }
    end)
    group = doc.at_css("[data-slot=menubar-group]")
    separator = doc.at_css("[data-slot=menubar-separator]")
    label = doc.at_css("[data-slot=menubar-label]")
    shortcut = doc.at_css("[data-slot=menubar-shortcut]")

    assert_equal "group", group["role"]
    assert_includes group["class"], "g-extra"
    assert_equal %w[separator horizontal], [ separator["role"], separator["aria-orientation"] ]
    assert_includes separator["class"], "s-extra"
    assert_equal "true", label["data-inset"]
    assert_includes label["class"], "l-extra"
    assert_equal %w[span Ctrl], [ shortcut.name, shortcut.text ]
    assert_includes shortcut["class"], "k-extra"
  end

  test "group, separator and item accept as_child with a tag" do
    doc = fragment(bar do
      render(Menubar::Group.new(as_child: :section)) { "g" }
      render(Menubar::Separator.new(as_child: :hr))
      render(Menubar::Item.new(as_child: :a, href: "/x")) { "i" }
    end)

    assert_equal "section", doc.at_css("[data-slot=menubar-group]").name
    assert_equal "hr", doc.at_css("[data-slot=menubar-separator]").name
    assert_equal "a", doc.at_css("[data-slot=menubar-item]").name
  end

  test "content serialises positioning options into the template and defaults to bottom start" do
    template = fragment(bar).at_css("template[data-shadcn--menubar-template]")
    options = JSON.parse(template["data-options"])

    assert_equal "bottom", options["side"]
    assert_equal 8, options["sideOffset"]
    assert_equal "start", options["align"]
    assert_equal(-4, options["alignOffset"])
    refute options["loop"]

    custom = JSON.parse(fragment(bar(content: { side: :top, side_offset: 2, loop: true })).at_css("template")["data-options"])

    assert_equal [ "top", 2, true ], custom.values_at("side", "sideOffset", "loop")
  end

  test "content merges class, keeps caller style and the radix style variables" do
    content = fragment(bar(content: { class: "c-extra", style: "color: red" })).at_css("[data-slot=menubar-content]")

    assert_includes content["class"], "c-extra"
    assert_includes content["style"], "color: red"
    assert_includes content["style"], "--radix-menubar-content-available-width"
    assert_equal "menu", content["role"]
  end

  test "trigger merges class and exposes its content id" do
    trigger = fragment(bar(trigger: { class: "t-extra" })).at_css("[data-slot=menubar-trigger]")
    content = fragment(bar).at_css("[data-slot=menubar-content]")

    assert_includes trigger["class"], "t-extra"
    assert_equal content["id"], trigger["data-shadcn--menubar-content-id"]
  end

  test "sub renders closed by default, open when default_open and controlled when open is given" do
    sub = lambda do |**options|
      fragment(bar do
        render(Menubar::Sub.new(**options)) { render(Menubar::SubTrigger.new) { "More" } }
      end).at_css("[data-slot=menubar-sub-trigger]")
    end

    assert_equal %w[false closed false], [ sub.call["aria-expanded"], sub.call["data-state"], sub.call["data-shadcn--menubar-sub-controlled"] ]
    assert_equal "open", sub.call(default_open: true)["data-state"]
    assert sub.call(default_open: true)["aria-controls"]
    assert_equal %w[open true], [ sub.call(open: true)["data-state"], sub.call(open: true)["data-shadcn--menubar-sub-controlled"] ]
  end

  test "sub content serialises its options and a portal makes it portal into its container" do
    html = bar do
      render(Menubar::Sub.new) do
        render(Menubar::SubTrigger.new) { "More" }
        render(Menubar::Portal.new(container: "#menus", force_mount: true)) { render(Menubar::SubContent.new) { "Deep" } }
      end
    end
    options = JSON.parse(fragment(html).at_css("template template")["data-options"])

    assert_equal [ true, "#menus", true ], options.values_at("portal", "container", "forceMount")

    in_place = JSON.parse(fragment(bar { render(Menubar::Sub.new) { render(Menubar::SubContent.new) { "Deep" } } }).at_css("template template")["data-options"])

    assert_equal [ false, 0, "start" ], in_place.values_at("portal", "sideOffset", "align")
    assert_nil in_place["container"]
  end

  test "a portal does not leak to the sub content nested inside another sub content" do
    html = bar do
      render(Menubar::Sub.new) do
        render(Menubar::Portal.new) do
          render(Menubar::SubContent.new) do
            render(Menubar::Sub.new) { render(Menubar::SubContent.new) { "Deepest" } }
          end
        end
      end
    end
    outer, inner = fragment(html).css("template[data-options]").select { |t| t["data-options"].include?("portal") }.map { |t| JSON.parse(t["data-options"]) }

    assert outer["portal"]
    refute inner["portal"]
  end

  test "sub content carries the root direction in its dir attribute" do
    html = bar(root: { dir: :rtl }) { render(Menubar::Sub.new) { render(Menubar::SubContent.new) { "x" } } }

    assert_equal "rtl", fragment(html).at_css("[data-slot=menubar-sub-content]")["dir"]
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

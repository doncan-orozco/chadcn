# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::CommandTest < Chadcn::TestCase
  Command = Chadcn::Command

  HELPERS = {
    dialog: Command::Dialog, input: Command::Input, list: Command::List, empty: Command::Empty, group: Command::Group,
    item: Command::Item, shortcut: Command::Shortcut, separator: Command::Separator
  }.freeze

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def values(node, *names) = names.map { |name| node[name] }

  def palette(root: {}, input: {}, list: {}, group: {}, item: {})
    fragment(render_view do
      render(Command.new(**root)) do
        render(Command::Input.new(**input))
        render(Command::List.new(**list)) do
          render(Command::Empty.new) { "No results found." }
          render(Command::Group.new(heading: "Suggestions", **group)) do
            render(Command::Item.new(**item)) { span { "Calendar" } }
            render(Command::Item.new(disabled: true)) { "Calculator" }
          end
          render Command::Separator.new
          render(Command::Item.new(value: " profile ")) do
            plain "Profile"
            render(Command::Shortcut.new { "⌘P" })
          end
        end
      end
    end)
  end

  test "root renders the label first and carries the controller values" do
    root = palette(root: { label: "Menu", class: "x-root", loop: true, default_value: "profile" }).at_css("[data-slot=command]")

    assert_equal "div", root.name
    assert_equal "-1", root["tabindex"]
    assert_equal "", root["cmdk-root"]
    assert_includes root["class"], "bg-popover"
    assert_includes root["class"], "x-root"
    assert_equal "chadcn--command", root["data-controller"]
    assert_equal "true", root["data-chadcn--command-loop-value"]
    assert_equal "profile", root["data-chadcn--command-value-value"]
    assert_equal "false", root["data-chadcn--command-controlled-value"]
    label = root.element_children.first

    assert_equal "label", label.name
    assert_equal "Menu", label.text
    assert_equal root.at_css("input")["id"], label["for"]
  end

  test "controlled value is trimmed and flagged, default_value is kept as is" do
    controlled = palette(root: { value: " billing " }).at_css("[data-slot=command]")
    uncontrolled = palette(root: { default_value: " billing " }).at_css("[data-slot=command]")

    assert_equal "billing", controlled["data-chadcn--command-value-value"]
    assert_equal "true", controlled["data-chadcn--command-controlled-value"]
    assert_equal " billing ", uncontrolled["data-chadcn--command-value-value"]
  end

  test "caller attributes reach the root and tabindex can be overridden" do
    root = palette(root: { tab_index: 0, id: "palette", data: { test: "x" } }).at_css("[data-slot=command]")

    assert_equal "0", root["tabindex"]
    assert_equal "palette", root["id"]
    assert_equal "x", root["data-test"]
    assert_equal "chadcn--command", root["data-controller"]
  end

  test "input wires the combobox to the list and label and ignores overriding attributes" do
    doc = palette(input: { placeholder: "Search...", class: "h-12", id: "ignored", type: "search", role: "x", disabled: true })
    input = doc.at_css("[data-slot=command-input]")

    assert_equal "div", input.parent.name
    assert_equal "command-input-wrapper", input.parent["data-slot"]
    assert doc.at_css("[data-slot=command-input-wrapper] > svg.lucide-search")
    assert_includes input["class"], "h-12"
    refute_includes input["class"], "h-10"
    assert_equal "Search...", input["placeholder"]
    assert input.key?("disabled")
    assert_equal "text", input["type"]
    assert_equal "combobox", input["role"]
    assert_equal doc.at_css("[cmdk-list]")["id"], input["aria-controls"]
    assert_equal doc.at_css("label[cmdk-label]")["id"], input["aria-labelledby"]
    assert_equal input["id"], doc.at_css("label")["for"]
    assert_equal %w[off off false list true], values(input, "autocomplete", "autocorrect", "spellcheck", "aria-autocomplete", "aria-expanded")
    assert_nil input["aria-activedescendant"]
    assert_nil input["data-chadcn--command-search"]
  end

  test "controlled input value is the search" do
    input = palette(input: { value: "cal" }).at_css("[data-slot=command-input]")

    assert_equal "cal", input["value"]
    assert_equal "cal", input["data-chadcn--command-search"]
  end

  test "list wraps its content in the sizer and labels the listbox" do
    list = palette(list: { label: "Commands", class: "max-h-[120px]" }).at_css("[data-slot=command-list]")

    assert_equal "listbox", list["role"]
    assert_equal "Commands", list["aria-label"]
    assert_equal "-1", list["tabindex"]
    assert_includes list["class"], "max-h-[120px]"
    assert list.at_css("> [cmdk-list-sizer]")
    assert_equal "Suggestions", palette.at_css("[data-slot=command-list]")["aria-label"]
  end

  test "empty ships its markup in an inert template and a caller class replaces the default" do
    template = palette.at_css("[cmdk-list-sizer] > template[data-chadcn--command-target=empty]")
    empty = template.at_css("[data-slot=command-empty]")

    assert_equal "No results found.", empty.text
    assert_equal "presentation", empty["role"]
    assert_equal "py-6 text-center text-sm", empty["class"]

    replaced = fragment(render_view do
      render(Command.new) { render(Command::List.new) { render(Command::Empty.new(class: "py-2 text-xs")) { "None" } } }
    end).at_css("[data-slot=command-empty]")

    assert_equal "py-2 text-xs", replaced["class"]
  end

  test "group renders heading and items wrapper with the value rules" do
    group = palette.at_css("[data-slot=command-group]")

    assert_equal "presentation", group["role"]
    assert_equal "Suggestions", group["data-value"]
    heading = group.at_css("[cmdk-group-heading]")

    assert_equal "true", heading["aria-hidden"]
    items = group.at_css("[cmdk-group-items]")

    assert_equal "group", items["role"]
    assert_equal heading["id"], items["aria-labelledby"]
    assert_equal " g ", palette(group: { value: " g " }).at_css("[data-slot=command-group]")["value"]
    assert_equal "g", palette(group: { value: " g " }).at_css("[data-slot=command-group]")["data-value"]

    bare = fragment(render_view { render(Command.new) { render(Command::Group.new) { "x" } } }).at_css("[data-slot=command-group]")

    assert_equal "undefined", bare["data-value"]
    assert_nil bare.at_css("[cmdk-group-heading]")
    assert_nil bare.at_css("[cmdk-group-items]")["aria-labelledby"]
    assert_equal "true", palette(group: { force_mount: true }).at_css("[data-slot=command-group]")["data-chadcn--command-force-mount"]
  end

  test "item renders the option state and ignores overriding attributes" do
    items = palette(item: { keywords: [ " agenda ", "events" ], id: "custom", role: "menuitem", data: { test: "one" } }).css("[data-slot=command-item]")
    first = items[0]

    assert_equal "option", first["role"]
    assert_match(/\Acommand-\d+-item-1\z/, first["id"])
    assert_equal %w[false false false false], values(first, "aria-disabled", "aria-selected", "data-disabled", "data-selected")
    assert_equal "one", first["data-test"]
    assert_equal %w[agenda events], JSON.parse(first["data-chadcn--command-keywords"])
    assert_nil first["data-value"]
    assert_equal %w[true true], values(items[1], "aria-disabled", "data-disabled")
    assert_equal "profile", items[2]["data-value"]
    assert_nil items[1]["data-chadcn--command-keywords"]
    assert_equal [ "Profile⌘P" ], [ items[2].text ]
  end

  test "item force_mount and as_child" do
    forced = palette(item: { force_mount: true }).at_css("[data-slot=command-item]")

    assert_equal "true", forced["data-chadcn--command-force-mount"]
    link = fragment(render_view do
      render(Command.new) { render(Command::Item.new(as_child: :a, href: "#billing", class: "x-item")) { "Billing" } }
    end).at_css("[data-slot=command-item]")

    assert_equal "a", link.name
    assert_equal "option", link["role"]
    assert_equal "#billing", link["href"]
    assert_includes link["class"], "x-item"
  end

  test "item keywords default to a frozen constant" do
    assert_predicate Command::Item::KEYWORDS, :frozen?
    assert_empty Command::Item::KEYWORDS
  end

  test "separator and shortcut render their slots and flags" do
    doc = palette
    separator = doc.at_css("[data-slot=command-separator]")

    assert_equal "separator", separator["role"]
    assert_equal "", separator["cmdk-separator"]
    assert_nil separator["data-chadcn--command-always-render"]
    assert_equal "ml-auto text-xs tracking-widest text-muted-foreground", doc.at_css("[data-slot=command-shortcut]")["class"]
    always = fragment(render_view { render(Command.new) { render(Command::Separator.new(always_render: true, class: "my-2")) } })

    assert_equal "true", always.at_css("[data-slot=command-separator]")["data-chadcn--command-always-render"]
    assert_includes always.at_css("[data-slot=command-separator]")["class"], "my-2"
  end

  test "data-slot can be overridden by the caller like in React" do
    assert_equal "custom-item", palette(item: { data: { slot: "custom-item" } }).at_css("[cmdk-item]")["data-slot"]
  end

  test "parts outside a Command raise" do
    error = assert_raises(ArgumentError) { render_view { render(Command::Item.new) { "x" } } }

    assert_match(/within Command/, error.message)
  end

  test "ids are unique per command and per render sequence" do
    html = render_view do
      render(Command.new) { render(Command::List.new) { render(Command::Item.new) { "a" } } }
      render(Command.new) { render(Command::List.new) { render(Command::Item.new) { "b" } } }
    end
    ids = fragment(html).css("[id]").map { |node| node["id"] }

    assert_equal ids.uniq, ids
  end

  test "dialog renders the sr-only header, the content and the command with the dialog classes" do
    html = render_view do
      render(Command::Dialog.new(default_open: true, title: "Search docs", class: "sm:max-w-md", "data-test": "d")) do |command|
        command.input
        command.list { command.empty { "None" } }
      end
    end
    doc = fragment(html)
    host = doc.at_css("[data-controller=chadcn--dialog]")

    assert_equal "d", host["data-test"]
    assert_equal "true", host["data-chadcn--dialog-open-value"]
    header = host.at_css("> [data-slot=dialog-header]")

    assert_includes header["class"], "sr-only"
    assert_equal "Search docs", header.at_css("[data-slot=dialog-title]").text
    assert_equal "Search for a command to run...", header.at_css("[data-slot=dialog-description]").text
    content = doc.at_css("template [data-slot=dialog-content]")

    assert_includes content["class"], "overflow-hidden"
    assert_includes content["class"], "p-0"
    refute_includes content["class"], "p-6"
    assert_includes content["class"], "sm:max-w-md"
    command = content.at_css("[data-slot=command]")

    assert_includes command["class"], Command::DIALOG_COMMAND_CLASSES.split.first
    assert content.at_css("[data-slot=dialog-close]")
    assert command.at_css("[data-slot=command-input]")
  end

  test "dialog can hide the close button and stay controlled" do
    html = render_view { render(Command::Dialog.new(show_close_button: false, open: false, modal: false), &:list) }
    doc = fragment(html)

    assert_nil doc.at_css("[data-slot=dialog-close]")
    assert_equal "true", doc.at_css("[data-controller=chadcn--dialog]")["data-chadcn--dialog-controlled-value"]
    assert_equal "false", doc.at_css("[data-controller=chadcn--dialog]")["data-chadcn--dialog-modal-value"]
  end

  test "every helper exists on the root and renders the same HTML as the explicit call" do
    explicit = render_view do
      render(Command.new) do
        render(Command::Input.new(placeholder: "q"))
        render(Command::List.new) do
          render(Command::Empty.new) { "None" }
          render(Command::Group.new(heading: "G")) do
            render(Command::Item.new { "I" })
            render(Command::Shortcut.new { "S" })
          end
          render Command::Separator.new
        end
      end
    end
    helper = render_view do
      render(Command.new) do |command|
        command.input(placeholder: "q")
        command.list do
          command.empty { "None" }
          command.group(heading: "G") do
            command.item { "I" }
            command.shortcut { "S" }
          end
          command.separator
        end
      end
    end

    assert_equal explicit, helper
    nested = fragment(render_view { render(Command.new) { |command| command.dialog(default_open: true, title: "T", &:list) } })

    assert_equal "T", nested.at_css("[data-slot=dialog-title]").text
    HELPERS.each do |name, part|
      assert Command.public_method_defined?(name), "missing helper ##{name}"
      assert_equal part, Command.const_get(name.to_s.capitalize)
    end
  end

  test "no third-party JavaScript is pinned for cmdk" do
    root = File.expand_path("../..", __dir__)
    pins = File.read(File.join(root, "config/importmap.rb"))

    refute_match(/cmdk|command-score/, pins)
    refute(Dir.glob(File.join(root, "{vendor,app}/javascript/**/*")).any? { |file| File.file?(file) && File.basename(file).match?(/cmdk|command-score/) })
  end

  test "id stays on the root and seeds the ids of the input, label, list and items" do
    doc = palette(root: { id: "palette" })
    input = doc.at_css("[data-slot=command-input]")

    assert_equal "palette", doc.at_css("[data-slot=command]")["id"]
    assert_equal "palette-input", input["id"]
    assert_equal "palette-list", input["aria-controls"]
    assert_equal "palette-label", input["aria-labelledby"]
    assert_equal "palette-input", doc.at_css("label[cmdk-label]")["for"]
    assert_equal "palette-list", doc.at_css("[data-slot=command-list]")["id"]
    assert_equal "palette-item-1", doc.at_css("[data-slot=command-item]")["id"]
  end
end

# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::ComboboxTest < Chadcn::TestCase
  Combobox = Chadcn::Combobox
  FRAMEWORKS = [ "Next.js", "SvelteKit", "Nuxt.js", "Remix", "Astro" ].freeze

  HELPERS = {
    input: Combobox::Input, trigger: Combobox::Trigger, clear: Combobox::Clear, value: Combobox::Value, content: Combobox::Content,
    list: Combobox::List, item: Combobox::Item, group: Combobox::Group, label: Combobox::Label, collection: Combobox::Collection,
    empty: Combobox::Empty, separator: Combobox::Separator, chips: Combobox::Chips, chip: Combobox::Chip,
    chips_input: Combobox::ChipsInput
  }.freeze

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  # The usual single-selection combobox; `root:`, `input:` and `content:` are the options of each part.
  def single(root: {}, input: {}, content: {})
    fragment(render_view do
      render(Combobox.new(items: FRAMEWORKS, **root)) do
        render Combobox::Input.new(placeholder: "Select a framework", **input)
        render(Combobox::Content.new(**content)) do
          render(Combobox::Empty.new { "No items found." })
          render(Combobox::List.new) { |item| render(Combobox::Item.new(value: item) { item }) }
        end
      end
    end)
  end

  def multiple(root: {}, chip: {})
    fragment(render_view do
      render(Combobox.new(items: FRAMEWORKS, multiple: true, **root)) do
        render Combobox::Chips.new do
          render(Combobox::Value.new) do |values|
            values.each { |value| render(Combobox::Chip.new(**chip) { value }) }
            render Combobox::ChipsInput.new(placeholder: "Add framework")
          end
        end
        render(Combobox::Content.new(anchor: "[data-slot=combobox-chips]")) do
          render(Combobox::List.new) { |item| render(Combobox::Item.new(value: item) { item }) }
        end
      end
    end)
  end

  # Nokogiri parses the content of a <template> as children: the nodes of the live document are the ones outside any template.
  def live(node, selector) = node.css(selector).reject { |match| match.ancestors("template").any? }

  def attrs(nodes, name) = nodes.map { |node| node[name] }

  def config_of(doc) = JSON.parse(doc.at_css("[data-controller]")["data-chadcn--combobox-config-value"])

  def popup_html(doc) = fragment(doc.at_css("template[data-chadcn--combobox-part=content-template]").inner_html)

  test "the root renders one display: contents host with the controller values and no data-slot" do
    host = single(root: { default_value: "Astro", name: "framework" }).at_css("[data-controller]")

    assert_equal "div", host.name
    assert_equal "display: contents", host["style"]
    assert_equal "chadcn--combobox", host["data-controller"]
    assert_nil host["data-slot"]
    assert_nil host["class"]
    assert_equal '["Astro"]', host["data-chadcn--combobox-selected-value"]
    assert_equal "false", host["data-chadcn--combobox-open-value"]
    assert_equal "Astro", host["data-chadcn--combobox-input-value-value"]
    config = JSON.parse(host["data-chadcn--combobox-config-value"])

    assert_equal(FRAMEWORKS, config["items"].map { |item| item["k"] })
    assert_equal "fuzzy", config["filter"]
    assert_equal "framework", config["name"]
  end

  test "a single combobox renders one hidden input that submits the serialized value" do
    named = single(root: { default_value: "Remix", name: "framework", form: "f", auto_complete: "off", required: true }).at_css("input[aria-hidden=true]")

    assert_equal "Remix", named["value"]
    assert_equal "framework", named["name"]
    assert_nil named["id"]
    assert_equal "-1", named["tabindex"]
    assert_equal "f", named["form"]
    assert_equal "off", named["autocomplete"]
    assert named.key?("required")
    assert_includes named["style"], "margin: -1px; position: absolute;"

    anonymous = single(root: { id: "fw", disabled: true, read_only: true }).at_css("input[aria-hidden=true]")

    assert_equal "fw-hidden-input", anonymous["id"]
    assert_nil anonymous["name"]
    assert_equal "", anonymous["value"]
    assert anonymous.key?("disabled")
    assert anonymous.key?("readonly")
    assert_includes anonymous["style"], "margin: 0px; position: fixed; top: 0px; left: 0px;"
  end

  test "a multiple combobox submits one hidden input per selected value, in selection order" do
    doc = multiple(root: { default_value: [ "Remix", "Next.js" ], name: "frameworks", required: true })
    base = doc.at_css("input[aria-hidden=true]")
    values = doc.css("input[type=hidden]")

    assert_equal %w[Remix Next.js], attrs(values, "value")
    assert_equal %w[frameworks frameworks], attrs(values, "name")
    assert_nil base["name"]
    assert_equal "combobox-1-hidden-input", base["id"]
    assert_equal "", base["value"]
    refute base.key?("required"), "a selection satisfies required"
    assert multiple(root: { name: "frameworks", required: true }).at_css("input[aria-hidden=true]").key?("required")
  end

  test "multiple without a name renders no value inputs" do
    assert_empty multiple(root: { default_value: [ "Remix" ] }).css("input[type=hidden]")
  end

  test "the input is the shadcn composition: an input group with the control, the trigger and the clear button" do
    doc = single(input: { class: "w-48", show_clear: true }, root: { default_value: "Remix" })
    group = doc.at_css("[data-slot=input-group]")
    control = doc.at_css("[data-slot=input-group-control]")
    addon = doc.at_css("[data-slot=input-group-addon]")

    assert_equal "group", group["role"]
    assert_includes group["class"].split, "w-48"
    refute_includes group["class"].split, "w-auto"
    refute_includes group["class"].split, "w-full"
    assert_equal "combobox", control["role"]
    assert_equal "combobox-1", control["id"]
    assert_equal "Remix", control["value"]
    assert_equal "Select a framework", control["placeholder"]
    assert_equal(%w[off false off none], %w[autocomplete spellcheck autocorrect autocapitalize].map { |name| control[name] })
    assert_equal(%w[false listbox list], [ control["aria-expanded"], control["aria-haspopup"], control["aria-autocomplete"] ])
    assert_nil control["aria-controls"]
    assert_equal "inline-end", addon["data-align"]
    trigger = addon.at_css("[data-slot=input-group-button]")

    assert_equal "button", trigger.name
    assert_equal %w[ghost icon-xs], [ trigger["data-variant"], trigger["data-size"] ]
    assert_equal "-1", trigger["tabindex"]
    assert_equal "listbox", trigger["aria-haspopup"]
    assert_includes trigger["class"], "data-pressed:bg-transparent"
    assert_includes trigger["class"], "group-has-data-[slot=combobox-clear]/input-group:hidden"
    assert_equal "combobox-trigger-icon", trigger.at_css("svg")["data-slot"]
    assert_includes trigger.at_css("svg")["class"], "text-muted-foreground"
    assert_nil trigger["data-placeholder"]
    clear = live(addon, "[data-slot=combobox-clear]").first

    assert_equal %w[ghost icon-xs], [ clear["data-variant"], clear["data-size"] ]
    assert_equal "", clear["data-visible"]
    assert_equal "lucide lucide-x pointer-events-none", clear.at_css("svg")["class"]
  end

  test "attributes reach the input element and id: overrides the root id for the input only" do
    doc = single(input: { id: "framework-input", name: "framework", required: true, "data-testid": "fw", "aria-label": "Framework" },
                 root: { id: "fw", required: true })
    control = doc.at_css("[data-slot=input-group-control]")

    assert_equal "framework-input", control["id"]
    assert_equal "framework", control["name"]
    assert_equal "fw", control["data-testid"]
    assert_equal "Framework", control["aria-label"]
    assert_equal "true", control["aria-required"]
    assert control.key?("required")
    assert_equal "fw-0", popup_html(doc).at_css("[data-slot=combobox-item]")["id"]
  end

  test "disabled: only disables the rendered controls; the root disabled marks every state" do
    control = single(input: { disabled: true }).at_css("[data-slot=input-group-control]")
    trigger = single(input: { disabled: true }).at_css("[data-slot=input-group-button]")

    assert control.key?("disabled")
    assert_nil control["data-disabled"]
    assert trigger.key?("disabled")
    assert_equal "", trigger["data-disabled"]
    root_disabled = single(root: { disabled: true }).at_css("[data-slot=input-group-control]")

    assert_equal "", root_disabled["data-disabled"]
    refute root_disabled.key?("disabled")
  end

  test "show_trigger: false drops the chevron and read_only/required reach the aria attributes" do
    doc = single(input: { show_trigger: false }, root: { read_only: true, required: true })

    assert_nil doc.at_css("[data-slot=input-group-button]")
    control = doc.at_css("[data-slot=input-group-control]")

    assert_equal "none", control["aria-autocomplete"]
    assert_equal "true", control["aria-readonly"]
    assert control.key?("readonly")
    assert_equal "true", control["aria-required"]
    assert_equal "", control["data-readonly"]
  end

  test "the open state renders the expanded attributes and the dismiss button" do
    doc = single(root: { default_open: true })
    control = doc.at_css("[data-slot=input-group-control]")

    assert_equal "true", control["aria-expanded"]
    assert_equal "combobox-1-list", control["aria-controls"]
    assert_equal [ "", "" ], [ control["data-popup-open"], control["data-pressed"] ]
    dismiss = doc.at_css("[data-slot=input-group] > span[role=button][aria-label=Dismiss]")

    assert dismiss
    assert_equal control, dismiss.next_element
  end

  test "an empty or static list reports data-list-empty" do
    assert_equal "", single(root: { items: [] }).at_css("[data-slot=input-group-control]")["data-list-empty"]
    assert_nil single.at_css("[data-slot=input-group-control]")["data-list-empty"]
    static = fragment(render_view do
      render(Combobox.new) do
        render Combobox::Input.new
        render(Combobox::Content.new) { render(Combobox::List.new) { render(Combobox::Item.new(value: "apple") { "Apple" }) } }
      end
    end)

    assert_equal "", static.at_css("[data-slot=input-group-control]")["data-list-empty"]
    assert_equal "", popup_html(static).at_css("[data-slot=combobox-list]")["data-empty"]
    assert_equal "apple", popup_html(static).at_css("[data-slot=combobox-item]")["data-chadcn--combobox-key"]
  end

  test "the content ships in an inert template with the positioner, popup classes and options" do
    doc = single(content: { side: :inline_end, align: "end", side_offset: 8, align_offset: -4, class: "w-60" })
    template = doc.at_css("template[data-chadcn--combobox-part=content-template]")
    options = JSON.parse(template["data-chadcn--combobox-options"])

    assert_equal({ "side" => "inline-end", "sideOffset" => 8, "align" => "end", "alignOffset" => -4, "anchor" => nil }, options)
    positioner = popup_html(doc).at_css("div[role=presentation]")

    assert_equal "isolate z-50", positioner["class"]
    popup = positioner.at_css("[data-slot=combobox-content]")

    assert_equal "-1", popup["tabindex"]
    assert_equal "presentation", popup["role"]
    assert_equal "false", popup["data-chips"]
    assert_includes popup["class"], "w-60"
    assert_includes popup["class"], "group/combobox-content"
    assert_includes popup["class"], "data-[chips=true]:min-w-(--anchor-width)"
    assert_empty live(doc, "[data-slot=combobox-content]"), "nothing of the popup is in the document"
  end

  test "an anchor marks the popup data-chips and travels as the positioning selector" do
    doc = multiple
    options = JSON.parse(doc.at_css("template[data-chadcn--combobox-part=content-template]")["data-chadcn--combobox-options"])

    assert_equal "[data-slot=combobox-chips]", options["anchor"]
    assert_equal "true", popup_html(doc).at_css("[data-slot=combobox-content]")["data-chips"]
  end

  test "the list calls the block once per root item and the items carry their identity" do
    items = [ "Next.js", { value: "remix", label: "Remix" }, { "value" => "astro", "label" => "Astro" } ]
    doc = popup_html(single(root: { default_value: "Remix", items: items }))
    list = doc.at_css("[data-slot=combobox-list]")
    items = doc.css("[data-slot=combobox-item]")

    assert_equal "listbox", list["role"]
    assert_equal "-1", list["tabindex"]
    assert_equal "combobox-1-list", list["id"]
    assert_equal 3, items.size
    assert_equal %w[combobox-1-0 combobox-1-1 combobox-1-2], attrs(items, "id")
    assert_equal %w[option], attrs(items, "role").uniq
    assert_equal %w[Next.js remix astro], attrs(items, "data-chadcn--combobox-key")
  end

  test "Hash items accept Symbol and String keys alike and submit their value" do
    symbols = { value: "remix", label: "Remix" }
    strings = { "value" => "remix", "label" => "Remix" }
    [ symbols, strings ].each do |item|
      doc = single(root: { items: [ item ], default_value: strings })
      config = JSON.parse(doc.at_css("[data-controller]")["data-chadcn--combobox-config-value"])

      assert_equal [ { "k" => "remix", "l" => "Remix" } ], config["items"]
      assert_equal "remix", doc.at_css("input[aria-hidden=true]")["value"]
      assert_equal "Remix", doc.at_css("[data-slot=input-group-control]")["value"]
    end
  end

  test "a scalar default_value picks the Hash item with that value, so its label is shown" do
    items = [ { value: "next", label: "Next.js" }, { value: "remix", label: "Remix" } ]
    doc = single(root: { items: items, default_value: "remix", name: "framework" })

    assert_equal "Remix", doc.at_css("[data-slot=input-group-control]")["value"]
    assert_equal "remix", doc.at_css("input[aria-hidden=true]")["value"]
    assert_equal '["remix"]', doc.at_css("[data-controller]")["data-chadcn--combobox-selected-value"]
  end

  test "selected items are marked and get the check mark; disabled items are marked" do
    doc = popup_html(fragment(render_view do
      render(Combobox.new(items: FRAMEWORKS, default_value: "Remix")) do
        render Combobox::Input.new
        render(Combobox::Content.new) do
          render(Combobox::List.new) { |item| render(Combobox::Item.new(value: item, disabled: item == "Nuxt.js", class: "rounded-none") { item }) }
        end
      end
    end))
    selected = doc.at_css("[data-slot=combobox-item][aria-selected=true]")
    nuxt = doc.css("[data-slot=combobox-item]")[2]

    assert_equal "Remix", selected.text
    assert_equal "", selected["data-selected"]
    indicator = selected.at_css("[data-slot=combobox-item-indicator]")

    assert_equal "", indicator["data-selected"]
    assert_equal "true", indicator["aria-hidden"]
    assert_includes indicator["class"], "absolute right-2"
    assert_includes indicator.at_css("svg")["class"], "pointer-coarse:size-5"
    assert_equal 1, doc.css("[data-slot=combobox-list] > [data-slot=combobox-item] [data-slot=combobox-item-indicator]").size
    assert_equal [ "", "true" ], [ nuxt["data-disabled"], nuxt["aria-disabled"] ]
    assert_includes nuxt["class"], "rounded-none"
    refute_includes nuxt["class"], "rounded-sm"
  end

  test "groups name themselves with their label and a Collection renders the group items" do
    groups = [ { value: "Americas", items: [ "New York", "Chicago" ] }, { value: "Europe", items: [ "Paris" ] } ]
    doc = popup_html(fragment(render_view do
      render(Combobox.new(items: groups)) do
        render Combobox::Input.new
        render(Combobox::Content.new) do
          render(Combobox::List.new) do |group|
            render(Combobox::Group.new(items: group[:items])) do
              render(Combobox::Label.new { group[:value] })
              render(Combobox::Collection.new) { |item| render(Combobox::Item.new(value: item) { item }) }
              render Combobox::Separator.new
            end
          end
        end
      end
    end))
    first = doc.at_css("[data-slot=combobox-group]")
    label = first.at_css("[data-slot=combobox-label]")

    assert_equal "group", first["role"]
    assert_equal label["id"], first["aria-labelledby"]
    assert_equal "true", label["aria-hidden"]
    assert_includes label["class"], "text-muted-foreground"
    assert_equal [ "New York", "Chicago" ], first.css("[data-slot=combobox-item]").map(&:text)
    assert_equal %w[combobox-1-0 combobox-1-1 combobox-1-2], attrs(doc.css("[data-slot=combobox-item]"), "id")
    assert_equal 2, doc.css("[data-slot=combobox-separator]").size
    separator = first.at_css("[data-slot=combobox-separator]")

    assert_equal %w[presentation horizontal], [ separator["role"], separator["data-orientation"] ]
    refute_equal label["id"], doc.css("[data-slot=combobox-label]").last["id"]
  end

  test "empty is a live region and keeps its content" do
    empty = popup_html(single).at_css("[data-slot=combobox-empty]")

    assert_equal "status", empty["role"]
    assert_equal "polite", empty["aria-live"]
    assert_equal "true", empty["aria-atomic"]
    assert_equal "No items found.", empty.text
    assert_includes empty["class"], "group-data-empty/combobox-content:flex"
  end

  test "value renders the label as bare text, the placeholder, or the block, and renders no element" do
    texts = lambda do |root, placeholder|
      fragment(render_view do
        render(Combobox.new(items: FRAMEWORKS, **root)) do
          render(Combobox::Trigger.new) { render Combobox::Value.new(placeholder: placeholder) }
        end
      end).at_css("[data-slot=combobox-trigger]")
    end

    selected = texts.call({ default_value: "Astro" }, "Pick")
    placeholder = texts.call({}, "Pick")

    assert_equal "Astro", selected.xpath("text()").text
    assert_equal "Pick", placeholder.xpath("text()").text
    assert_equal "", placeholder["data-placeholder"]
    assert_nil selected["data-placeholder"]
    assert_nil selected.at_css("[data-slot=combobox-value]")
    assert_equal "Next.js, Astro", texts.call({ multiple: true, default_value: [ "Next.js", "Astro" ] }, nil).xpath("text()").text
    markers = attrs(selected.css("template"), "data-chadcn--combobox-part") - %w[value-prototype]

    assert_equal %w[value-start value-end], markers
  end

  test "a value block ships its output per item in prototype templates" do
    doc = fragment(render_view do
      render(Combobox.new(items: FRAMEWORKS, default_value: "Remix")) do
        render(Combobox::Trigger.new) { render(Combobox::Value.new) { |item| strong { item.to_s } } }
      end
    end)
    trigger = doc.at_css("[data-slot=combobox-trigger]")

    assert_equal "Remix", trigger.css("> strong").text
    prototypes = trigger.css("template[data-chadcn--combobox-part=value-prototype]")

    assert_equal FRAMEWORKS + [ "" ], attrs(prototypes, "data-key")
    assert_equal "<strong>Astro</strong>", prototypes.find { |template| template["data-key"] == "Astro" }.inner_html
  end

  test "the standalone trigger is the combobox when the input lives in the popup" do
    doc = fragment(render_view do
      render(Combobox.new(items: FRAMEWORKS, default_open: true)) do
        render(Combobox::Trigger.new(class: "w-64")) { render Combobox::Value.new }
        render(Combobox::Content.new) do
          render Combobox::Input.new(show_trigger: false, placeholder: "Search")
          render(Combobox::List.new) { |item| render(Combobox::Item.new(value: item) { item }) }
        end
      end
    end)
    trigger = doc.at_css("[data-slot=combobox-trigger]")

    assert_equal %w[button combobox dialog 0 combobox-1], [ trigger.name, trigger["role"], trigger["aria-haspopup"], trigger["tabindex"], trigger["id"] ]
    assert_equal "combobox-1-popup", trigger["aria-controls"]
    assert_includes trigger["class"], "w-64"
    assert_equal "", trigger["data-placeholder"]
    popup = popup_html(doc).at_css("[data-slot=combobox-content]")

    assert_equal %w[dialog combobox-1-popup], [ popup["role"], popup["id"] ]
    inner = popup.at_css("[data-slot=input-group-control]")

    assert_equal "", inner["value"]
    assert_equal "combobox-1-list", inner["aria-controls"]
    assert_nil popup_html(doc).at_css("[data-slot=input-group-button]")
  end

  test "chips render a toolbar only while something is selected, with removable chips and the chips input" do
    doc = multiple(root: { default_value: [ "Next.js", "Remix" ] })
    chips = doc.at_css("[data-slot=combobox-chips]")

    assert_equal "toolbar", chips["role"]
    assert_nil multiple.at_css("[data-slot=combobox-chips]")["role"]
    chip = live(doc, "[data-slot=combobox-chip]")

    assert_equal([ "Next.js", "Remix" ], chip.map { |node| node.xpath("text()").text })
    assert_equal "-1", chip.first["tabindex"]
    remove = chip.first.at_css("[data-slot=combobox-chip-remove]")

    assert_equal %w[button ghost icon-xs -1 false], [ remove.name, remove["data-variant"], remove["data-size"], remove["tabindex"], remove["aria-disabled"] ]
    assert_equal "button", remove["type"]
    assert_includes remove["class"], "-ml-1 opacity-50 hover:opacity-100"
    input = live(doc, "[data-slot=combobox-chip-input]").first

    assert_equal "Add framework", input["placeholder"]
    assert_includes input["class"], "min-w-16 flex-1 outline-none"
    assert_equal chips, input.parent
  end

  test "chip show_remove: false and a disabled root" do
    doc = multiple(root: { default_value: [ "Remix" ], disabled: true }, chip: { show_remove: false, class: "bg-primary" })
    chip = live(doc, "[data-slot=combobox-chip]").first

    assert_nil chip.at_css("[data-slot=combobox-chip-remove]")
    assert_equal [ "true", "" ], [ chip["aria-disabled"], chip["data-disabled"] ]
    assert_includes chip["class"].split, "bg-primary"
    refute_includes chip["class"].split, "bg-muted"
    disabled = live(multiple(root: { default_value: [ "Remix" ], disabled: true }), "[data-slot=combobox-chip-remove]").first

    assert_equal [ "true", "" ], [ disabled["aria-disabled"], disabled["data-disabled"] ]
    assert_equal "", live(doc, "[data-slot=combobox-chip-input]").first["data-disabled"]
  end

  test "chips input prefers disabled: over the root state" do
    input = fragment(render_view do
      render(Combobox.new(items: FRAMEWORKS, multiple: true)) do
        render(Combobox::Chips.new) { render Combobox::ChipsInput.new(disabled: true) }
      end
    end).at_css("[data-slot=combobox-chip-input]")

    assert input.key?("disabled")
    assert_equal "", input["data-disabled"]
  end

  test "class: is merged last through cn on every part" do
    doc = fragment(render_view do
      render(Combobox.new(items: FRAMEWORKS, multiple: true, default_value: [ "Astro" ])) do
        render(Combobox::Chips.new(class: "gap-4")) { render(Combobox::Chip.new(class: "text-sm")) { "x" } }
        render(Combobox::Content.new(class: "max-h-40")) do
          render(Combobox::Empty.new(class: "py-4")) { "none" }
          render(Combobox::List.new(class: "p-2")) { |item| render(Combobox::Item.new(value: item, class: "py-3")) { item } }
        end
      end
    end)
    popup = popup_html(doc)

    assert_includes doc.at_css("[data-slot=combobox-chips]")["class"].split, "gap-4"
    refute_includes doc.at_css("[data-slot=combobox-chips]")["class"].split, "gap-1.5"
    assert_includes live(doc, "[data-slot=combobox-chip]").first["class"].split, "text-sm"
    assert_includes popup.at_css("[data-slot=combobox-content]")["class"].split, "max-h-40"
    refute_includes popup.at_css("[data-slot=combobox-content]")["class"].split, "max-h-96"
    assert_includes popup.at_css("[data-slot=combobox-empty]")["class"].split, "py-4"
    assert_includes popup.at_css("[data-slot=combobox-list]")["class"].split, "p-2"
    assert_includes popup.at_css("[data-slot=combobox-item]")["class"].split, "py-3"
    refute_includes popup.at_css("[data-slot=combobox-item]")["class"].split, "py-1.5"
  end

  test "a tag symbol or component as_child receives the trigger props" do
    doc = fragment(render_view do
      render(Combobox.new(items: FRAMEWORKS)) do
        render(Combobox::Trigger.new(as_child: :span, class: "x")) { "Open" }
      end
    end)
    trigger = doc.at_css("[data-slot=combobox-trigger]")

    assert_equal "span", trigger.name
    assert_equal "dialog", trigger["aria-haspopup"]
    assert_equal "button", trigger["type"]

    assert_includes trigger["class"].split, "x"
  end

  test "string and symbol options mean the same" do
    explicit = single(root: { auto_highlight: "always", filter: "contains" }, content: { side: "inline-end" })
    symbols = single(root: { auto_highlight: :always, filter: :contains }, content: { side: :inline_end })
    modes = ->(doc) { config_of(doc).values_at("autoHighlight", "filter") }

    assert_equal %w[always contains], modes.call(explicit)
    assert_equal modes.call(explicit), modes.call(symbols)
    assert_equal explicit.to_html, symbols.to_html
    assert_equal [ true, nil ], modes.call(single(root: { auto_highlight: true, filter: nil }))
  end

  test "an unknown filter raises" do
    error = assert_raises(ArgumentError) { single(root: { filter: "starts_with" }) }

    assert_match(/unknown filter/, error.message)
  end

  test "item_to_string_label, item_to_string_value and item_equal_to_value are evaluated on the server" do
    people = [ { id: 1, name: "Ana" }, { id: 2, name: "Bo" } ]
    doc = fragment(render_view do
      render(Combobox.new(items: people, default_value: { id: 2 }, name: "person",
                          item_to_string_label: ->(item) { item[:name] }, item_to_string_value: ->(item) { item[:id].to_s },
                          item_equal_to_value: ->(item, value) { item[:id] == value[:id] })) do
        render Combobox::Input.new
      end
    end)

    assert_equal "Bo", doc.at_css("[data-slot=input-group-control]")["value"]
    assert_equal "2", doc.at_css("input[aria-hidden=true]")["value"]
    assert_equal '["2"]', doc.at_css("[data-controller]")["data-chadcn--combobox-selected-value"]
    assert_equal(%w[Ana Bo], config_of(doc)["items"].map { |item| item["l"] })
  end

  test "a part outside Combobox raises" do
    [ Combobox::Input, Combobox::Trigger, Combobox::List, Combobox::Item, Combobox::Empty ].each do |part|
      assert_raises(ArgumentError, part.name) { render_view { render part.new } }
    end
  end

  test "the generated helpers render the same HTML as the explicit parts" do
    explicit = render_view do
      render(Combobox.new(items: FRAMEWORKS, default_value: "Remix")) do
        render Combobox::Input.new(placeholder: "Pick", show_clear: true)
        render(Combobox::Content.new(side: "top")) do
          render(Combobox::Empty.new(class: "py-4")) { "None" }
          render(Combobox::List.new) { |item| render(Combobox::Item.new(value: item, class: "x")) { item } }
        end
      end
    end
    helpers = render_view do
      render(Combobox.new(items: FRAMEWORKS, default_value: "Remix")) do |combobox|
        combobox.input(placeholder: "Pick", show_clear: true)
        combobox.content(side: "top") do
          combobox.empty(class: "py-4") { "None" }
          combobox.list { |item| combobox.item(value: item, class: "x") { item } }
        end
      end
    end

    assert_equal explicit, helpers
  end

  test "every part has a helper on the root that matches the explicit render" do
    HELPERS.each do |name, part|
      assert Combobox.public_method_defined?(name), "missing helper ##{name}"
      assert_equal part, Combobox.const_get(name.to_s.split("_").map(&:capitalize).join)
    end
    groups = [ { value: "G", items: [ "a" ] } ]
    explicit = render_view do
      render(Combobox.new(items: groups, multiple: true, default_value: [ "a" ])) do
        render(Combobox::Chips.new) do
          render(Combobox::Value.new(placeholder: "p")) do |values|
            values.each { |value| render(Combobox::Chip.new { value }) }
            render Combobox::ChipsInput.new
          end
        end
        render(Combobox::Trigger.new) { "t" }
        render Combobox::Clear.new
        render(Combobox::Content.new) do
          render(Combobox::List.new) do |group|
            render(Combobox::Group.new(items: group[:items])) do
              render(Combobox::Label.new { group[:value] })
              render(Combobox::Collection.new) { |item| render(Combobox::Item.new(value: item)) { item } }
              render Combobox::Separator.new
            end
          end
        end
      end
    end
    helpers = render_view do
      render(Combobox.new(items: groups, multiple: true, default_value: [ "a" ])) do |combobox|
        combobox.chips do
          combobox.value(placeholder: "p") do |values|
            values.each { |value| combobox.chip { value } }
            combobox.chips_input
          end
        end
        combobox.trigger { "t" }
        combobox.clear
        combobox.content do
          combobox.list do |group|
            combobox.group(items: group[:items]) do
              combobox.label { group[:value] }
              combobox.collection { |item| combobox.item(value: item) { item } }
              combobox.separator
            end
          end
        end
      end
    end

    assert_equal explicit, helpers
  end
end

# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::TooltipTest < Chadcn::TestCase
  CONFIG = {
    desktop: { label: "Desktop", color: "var(--chart-1)" },
    mobile: { label: "Mobile", color: "var(--chart-2)" },
    visitors: { label: "Visitors", icon: :bell, color: "var(--chart-3)" }
  }.freeze
  ROW = { month: "January", desktop: 186, mobile: 80 }.freeze

  def payload(*keys)
    keys.map { |key| { name: key.to_s, data_key: key.to_s, value: ROW.fetch(key), color: "var(--color-#{key})", payload: ROW } }
  end

  def render_content(config: CONFIG, **props)
    Class.new(Phlex::HTML) do
      define_method(:view_template) { render(Chadcn::Chart::Container.new(config: config, id: "t")) { render Chadcn::Chart::Tooltip::Content.new(**props) } }
    end.new.call
  end

  def box(html) = Nokogiri::HTML.fragment(html).at_css(".recharts-responsive-container > div > div")

  test "renders nothing for an empty payload" do
    assert_nil box(render_content(payload: []))
    assert_nil box(render_content)
  end

  test "renders the box, the label and one dot item per series" do
    node = box(render_content(payload: payload(:desktop, :mobile), label: "January"))
    rows = node.css("> .grid > div")

    assert_includes node["class"], "min-w-[8rem]"
    assert_includes node["class"], "shadow-xl"
    assert_equal "January", node.at_css("> .font-medium").text
    assert_equal(%w[Desktop Mobile], rows.map { |row| row.at_css("span.text-muted-foreground").text })
    assert_equal(%w[186 80], rows.map { |row| row.at_css("span.tabular-nums").text })
    assert_includes rows.first["class"].split, "items-center"
    assert_not_includes rows.first["class"].split, "items-stretch"
    indicator = rows.first.at_css("div.shrink-0")

    assert_includes indicator["class"], "h-2.5 w-2.5"
    assert_equal "--color-bg: var(--color-desktop); --color-border: var(--color-desktop);", indicator["style"]
  end

  test "a config key as the label is replaced by its label, a label key takes the row value" do
    assert_equal "Mobile", box(render_content(payload: payload(:desktop), label: "mobile")).at_css("> .font-medium").text
    assert_equal "Desktop", box(render_content(payload: payload(:desktop), label: "ignored", label_key: "desktop")).at_css("> .font-medium").text
  end

  test "without a label string the label is the config label of the first item" do
    assert_equal "Desktop", box(render_content(payload: payload(:desktop, :mobile))).at_css("> .font-medium").text
  end

  test "hide_label drops the label and label_class_name is merged" do
    assert_nil box(render_content(payload: payload(:desktop), label: "x", hide_label: true)).at_css("> .font-medium")
    assert_includes box(render_content(payload: payload(:desktop), label: "x", label_class_name: "text-red-500")).at_css("> .font-medium")["class"],
                    "text-red-500"
  end

  test "label_formatter replaces the label and receives the value and the payload" do
    seen = nil
    formatter = ->(value, items) { (seen = [ value, items.length ]) && "Month: #{value}" }
    node = box(render_content(payload: payload(:desktop), label: "mobile", label_formatter: formatter))

    assert_equal "Month: Mobile", node.at_css("> .font-medium").text
    assert_equal [ "Mobile", 1 ], seen
  end

  test "a single item with a line indicator nests the label next to the series name" do
    node = box(render_content(payload: payload(:desktop), label: "January", indicator: :line))

    assert_nil node.at_css("> .font-medium")
    assert_equal "January", node.at_css("div.flex-1 > div[class='grid gap-1.5'] > .font-medium").text
    assert_includes node.at_css("div.flex-1")["class"], "items-end"
    assert_includes node.at_css("div.shrink-0")["class"], "w-1"
    assert_not_includes node.at_css("div.shrink-0")["class"], "h-2.5"
  end

  test "a dot indicator never nests, even for one item" do
    node = box(render_content(payload: payload(:desktop), label: "January"))

    assert_equal "January", node.at_css("> .font-medium").text
    assert_includes node.at_css("div.flex-1")["class"], "items-center"
  end

  test "the dashed indicator has the dashed classes and my-0.5 only when nested" do
    two = box(render_content(payload: payload(:desktop, :mobile), indicator: :dashed)).at_css("div.shrink-0")
    one = box(render_content(payload: payload(:desktop), indicator: :dashed)).at_css("div.shrink-0")

    assert_includes two["class"], "w-0 border-[1.5px] border-dashed bg-transparent"
    assert_not_includes two["class"].split, "my-0.5"
    assert_includes one["class"].split, "my-0.5"
    assert_includes box(render_content(payload: payload(:desktop, :mobile), indicator: :dashed)).at_css("div[class=\"grid gap-1.5\"] > div")["class"].split,
                    "items-stretch"
  end

  test "an unknown indicator raises" do
    assert_raises(ArgumentError) { Chadcn::Chart::Tooltip::Content.new(indicator: :bar) }
  end

  test "hide_indicator drops the indicator but keeps the text" do
    node = box(render_content(payload: payload(:desktop), hide_indicator: true))

    assert_nil node.at_css("div.shrink-0")
    assert_equal "Desktop", node.at_css("span.text-muted-foreground").text
  end

  test "the config icon replaces the indicator" do
    item = [ { name: "visitors", data_key: "visitors", value: 3, color: "red" } ]
    node = box(render_content(payload: item))

    assert_nil node.at_css("div.shrink-0")
    assert node.at_css("div[class=\"grid gap-1.5\"] > div > svg")
  end

  test "the indicator color is the color kwarg, then the row fill, then the item color" do
    item = payload(:desktop)
    style = ->(html) { box(html).at_css("div.shrink-0")["style"] }

    assert_includes style.call(render_content(payload: item, color: "red")), "--color-bg: red;"
    assert_includes style.call(render_content(payload: [ item.first.merge(payload: ROW.merge(fill: "blue")) ])), "--color-bg: blue;"
    assert_includes style.call(render_content(payload: item)), "--color-bg: var(--color-desktop);"
  end

  test "name_key names the config entry through the row" do
    config = { chrome: { label: "Chrome" } }
    item = [ { name: "visitors", data_key: "visitors", value: 275, payload: { browser: "chrome", visitors: 275 } } ]
    node = box(render_content(config: config, payload: item, name_key: "browser"))

    assert_equal "Chrome", node.at_css("span.text-muted-foreground").text
  end

  test "skips payload items of type none" do
    items = payload(:desktop, :mobile).tap { |list| list.last[:type] = :none }

    assert_equal 1, box(render_content(payload: items)).css("span.tabular-nums").length
  end

  test "numbers are formatted like toLocaleString and other values are printed as given" do
    values = { 1860 => "1,860", 1_234_567.891 => "1,234,567.891", 0.5 => "0.5", 1.0005 => "1.001", -1234.5 => "-1,234.5", 0 => "0", "n/a" => "n/a" }
    values.each do |value, text|
      node = box(render_content(payload: [ { name: "desktop", value: value } ]))

      assert_equal text, node.at_css("span.tabular-nums").text, value.inspect
    end
    assert_nil box(render_content(payload: [ { name: "desktop", value: nil } ])).at_css("span.tabular-nums")
  end

  test "a formatter renders the item instead of the default markup" do
    calls = []
    formatter = ->(value, name, _item, index, row) { (calls << [ value, name, index, row[:month] ]) && "#{name}=#{value}" }
    node = box(render_content(payload: payload(:desktop, :mobile), formatter: formatter))

    assert_equal [ "desktop=186", "mobile=80" ], node.css("div[class=\"grid gap-1.5\"] > div").map(&:text)
    assert_equal [ [ 186, "desktop", 0, "January" ], [ 80, "mobile", 1, "January" ] ], calls
  end

  test "the formatter index counts only the items that are not of type none" do
    indexes = []
    formatter = ->(_value, name, _item, index, _row) { (indexes << [ name, index ]) && name }
    items = payload(:desktop, :mobile).tap { |list| list.first[:type] = :none }
    render_content(payload: items, formatter: formatter)

    assert_equal [ [ "mobile", 0 ] ], indexes
  end

  test "a formatter is skipped for an item without a value key or with a falsy name, and runs for an explicit nil value" do
    formatter = ->(*) { "formatted" }

    assert_not_includes box(render_content(payload: [ { name: "desktop" } ], formatter: formatter)).text, "formatted"
    assert_not_includes box(render_content(payload: [ { name: "", value: 1 } ], formatter: formatter)).text, "formatted"
    assert_not_includes box(render_content(payload: [ { name: 0, value: 1 } ], formatter: formatter)).text, "formatted"
    assert_includes box(render_content(payload: [ { name: "desktop", value: nil } ], formatter: formatter)).text, "formatted"
    assert_includes box(render_content(payload: [ { "name" => "desktop", "value" => nil } ], formatter: formatter)).text, "formatted"
  end

  test "a config label that is an empty string wins over the label like a nullish check" do
    node = box(render_content(config: { january: { label: "" } }, payload: payload(:desktop), label: "january"))

    assert_nil node.at_css("> .font-medium")
  end

  test "payload must be an Array of Hashes" do
    [ "x", { a: 1 }, [ 1 ], [ { a: 1 }, "x" ] ].each do |bad|
      error = assert_raises(ArgumentError) { Chadcn::Chart::Tooltip::Content.new(payload: bad) }

      assert_match(/payload: must be an Array of Hashes/, error.message)
    end
    assert_equal "", Chadcn::Chart::Tooltip::Content.new(payload: nil).call
  end

  test "the generated content helper of a Tooltip renders the same as the explicit class" do
    items = [ { name: "desktop", data_key: "desktop", value: 186, color: "red" } ]
    helper = Class.new(Chadcn::Chart::Tooltip) { define_method(:view_template) { content(indicator: :line, label: "January", payload: items) } }
    explicit = render_content(indicator: :line, label: "January", payload: items)
    through_helper = Class.new(Phlex::HTML) do
      define_method(:view_template) { render(Chadcn::Chart::Container.new(config: CONFIG, id: "t")) { render helper.new } }
    end.new.call

    assert_equal explicit, through_helper
  end

  test "attrs land on the root div" do
    node = box(render_content(payload: payload(:desktop), class: "w-40", data: { index: 1 }))

    assert_includes node["class"].split, "w-40"
    assert_equal "1", node["data-index"]
  end

  test "outside a container it raises like useChart" do
    error = assert_raises(ArgumentError) { Chadcn::Chart::Tooltip::Content.new(payload: payload(:desktop)).call }

    assert_includes error.message, "Chart::Container"
  end

  test "with returns a copy with other options" do
    base = Chadcn::Chart::Tooltip::Content.new(indicator: :line, hide_label: true, class: "w-40")
    copy = base.with(payload: payload(:desktop), label: "January")
    html = Class.new(Phlex::HTML) { define_method(:view_template) { render(Chadcn::Chart::Container.new(config: CONFIG, id: "t")) { render copy } } }.new.call
    node = box(html)

    assert_includes node["class"].split, "w-40"
    assert_includes node.at_css("div.shrink-0")["class"], "w-1"
    assert_nil node.at_css("> .font-medium")
  end

  test "Tooltip is a declaration: it renders nothing and keeps the recharts defaults" do
    content = Chadcn::Chart::Tooltip::Content.new
    tooltip = Chadcn::Chart::Tooltip.new(content: content, default_index: 1)

    assert_raises(ArgumentError) { tooltip.call } # a declaration renders only inside a chart
    assert_same content, tooltip.content_element
    assert_equal({ cursor: true, default_index: 1, active: nil, shared: nil, trigger: :hover, offset: 10 },
                 tooltip.options.slice(:cursor, :default_index, :active, :shared, :trigger, :offset))
    assert_equal [ 400, :ease, true ], tooltip.options.values_at(:animation_duration, :animation_easing, :filter_null)
    assert_predicate tooltip.options, :frozen?
  end

  test "Tooltip keeps non-default options and attrs, and rejects what it cannot use" do
    tooltip = Chadcn::Chart::Tooltip.new(cursor: false, trigger: "click", active: true, offset: { x: 1, y: 2 }, class: "z-10")

    assert_equal [ false, :click, true, { x: 1, y: 2 }, { class: "z-10" } ], tooltip.options.values_at(:cursor, :trigger, :active, :offset, :attrs)
    assert_raises(ArgumentError) { Chadcn::Chart::Tooltip.new(trigger: :tap) }
    assert_raises(ArgumentError) { Chadcn::Chart::Tooltip.new(content: Chadcn::Chart::Legend::Content.new) }
    assert_raises(ArgumentError) { Chadcn::Chart::Tooltip.new(active: "yes") }
    assert_raises(ArgumentError) { Chadcn::Chart::Tooltip.new(shared: 1) }
  end

  test "item rows of a non-dot indicator carry no stray class token" do
    %i[line dashed].each do |indicator|
      row = box(render_content(payload: payload(:desktop, :mobile), indicator: indicator)).at_css("div[class='grid gap-1.5'] > div")

      assert_not_includes row["class"].split, "false", indicator.to_s
      assert_includes row["class"].split, "items-stretch"
    end
  end

  test "the indicator may be given as a String" do
    node = box(render_content(payload: payload(:desktop), indicator: "line"))

    assert_includes node.at_css("div.shrink-0")["class"], "w-1"
  end

  test "payload items and rows with string keys are read like symbol keys" do
    item = { "name" => "desktop", "data_key" => "desktop", "value" => 186, "color" => "red", "payload" => { "fill" => "blue" } }
    node = box(render_content(payload: [ item ]))

    assert_equal "Desktop", node.at_css("span.text-muted-foreground").text
    assert_equal "186", node.at_css("span.tabular-nums").text
    assert_includes node.at_css("div.shrink-0")["style"], "--color-bg: blue;"
  end

  test "numbers that JavaScript prints specially" do
    values = { Float::INFINITY => "∞", -Float::INFINITY => "-∞", -0.0 => "-0", 12_345_678_901_234_567_890 => "12,345,678,901,234,567,890",
               Rational(1, 3) => "0.333", 999.9995 => "1,000" }

    values.each do |value, text|
      assert_equal text, box(render_content(payload: [ { name: "desktop", value: value } ])).at_css("span.tabular-nums").text, value.inspect
    end
    assert_equal "NaN", box(render_content(payload: [ { name: "desktop", value: Float::NAN } ])).at_css("span.tabular-nums").text
  end

  test "a formatter or label formatter may return a component" do
    component = Class.new(Phlex::HTML) { define_method(:view_template) { span(class: "custom") { "made" } } }
    node = box(render_content(payload: payload(:desktop), formatter: ->(*) { component.new }, label_formatter: ->(*) { component.new }))

    assert_equal 2, node.css("span.custom").length
  end

  test "a config icon may be a component instance" do
    icon = Class.new(Phlex::HTML) { define_method(:view_template) { svg(class: "mine") } }.new
    node = box(render_content(config: { desktop: { label: "Desktop", icon: icon } }, payload: payload(:desktop)))

    assert node.at_css("svg.mine")
    assert_nil node.at_css("div.shrink-0")
  end

  test "Tooltip keeps the formatters that override its content" do
    formatter = ->(*) { "x" }
    options = Chadcn::Chart::Tooltip.new(formatter: formatter, label_formatter: formatter, wrapper_style: { zIndex: 1 }, position: { x: 1 }).options

    assert_same formatter, options[:formatter]
    assert_same formatter, options[:label_formatter]
    assert_equal [ { zIndex: 1 }, { x: 1 } ], options.values_at(:wrapper_style, :position)
    assert_raises(ArgumentError) { Chadcn::Chart::Tooltip.new(trigger: nil) }
  end

  test "an item without any color writes no style attribute and a false label is not printed" do
    node = box(render_content(config: { desktop: { label: false } }, payload: [ { name: "desktop", value: 1 } ]))

    assert_nil node.at_css("div.shrink-0")["style"]
    assert_equal "", node.at_css("span.text-muted-foreground").text
  end

  test "an item without a config entry shows its own name" do
    node = box(render_content(config: { other: { label: "Other" } }, payload: [ { name: "desktop", value: 3 } ]))

    assert_equal "desktop", node.at_css("span.text-muted-foreground").text
  end

  test "a single non-dot item still lays out as nested when the label is hidden" do
    node = box(render_content(payload: payload(:desktop), indicator: :dashed, hide_label: true))

    assert_includes node.at_css("div.flex-1")["class"], "items-end"
    assert_includes node.at_css("div.shrink-0")["class"].split, "my-0.5"
  end
end

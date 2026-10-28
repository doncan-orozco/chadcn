# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::LegendTest < Chadcn::TestCase
  CONFIG = {
    desktop: { label: "Desktop", color: "var(--chart-1)" },
    mobile: { label: "Mobile", color: "var(--chart-2)" },
    visitors: { label: "Visitors", icon: :bell }
  }.freeze

  def payload(*keys) = keys.map { |key| { value: key.to_s, data_key: key.to_s, color: "var(--color-#{key})", type: :rect } }

  def render_content(config: CONFIG, **props)
    Class.new(Phlex::HTML) do
      define_method(:view_template) { render(Chadcn::Chart::Container.new(config: config, id: "l")) { render Chadcn::Chart::Legend::Content.new(**props) } }
    end.new.call
  end

  def box(html) = Nokogiri::HTML.fragment(html).at_css(".recharts-responsive-container > div > div")

  test "renders nothing for an empty payload" do
    assert_nil box(render_content(payload: []))
    assert_nil box(render_content)
  end

  test "renders a color dot and the config label per item, padded above by default" do
    node = box(render_content(payload: payload(:desktop, :mobile)))
    items = node.css("> div")

    assert_equal "flex items-center justify-center gap-4 pt-3", node["class"]
    assert_equal %w[Desktop Mobile], items.map(&:text)
    assert_equal "h-2 w-2 shrink-0 rounded-[2px]", items.first.at_css("div")["class"]
    assert_equal "background-color: var(--color-desktop);", items.first.at_css("div")["style"]
    assert_equal "flex items-center gap-1.5 [&>svg]:h-3 [&>svg]:w-3 [&>svg]:text-muted-foreground", items.first["class"]
  end

  test "vertical_align top pads below, bottom and middle pad above" do
    assert_equal "flex items-center justify-center gap-4 pb-3", box(render_content(payload: payload(:desktop), vertical_align: :top))["class"]
    assert_includes box(render_content(payload: payload(:desktop), vertical_align: "bottom"))["class"], "pt-3"
    assert_includes box(render_content(payload: payload(:desktop), vertical_align: :middle))["class"], "pt-3"
  end

  test "skips payload items of type none" do
    items = payload(:desktop, :mobile).tap { |list| list.first[:type] = :none }

    assert_equal %w[Mobile], box(render_content(payload: items)).css("> div").map(&:text)
  end

  test "the config icon replaces the dot unless hide_icon" do
    item = [ { data_key: "visitors", color: "red" } ]

    assert box(render_content(payload: item)).at_css("> div > svg")
    assert_nil box(render_content(payload: item)).at_css("> div > div")
    assert box(render_content(payload: item, hide_icon: true)).at_css("> div > div.rounded-\\[2px\\]")
  end

  test "name_key names the config entry through the row, an item without config renders only the dot" do
    node = box(render_content(payload: [ { data_key: "visitors", browser: "desktop", color: "red" }, { data_key: "other", color: "blue" } ],
                              name_key: "browser"))

    assert_equal [ "Desktop", "" ], node.css("> div").map(&:text)
  end

  test "attrs land on the root div" do
    node = box(render_content(payload: payload(:desktop), class: "mt-4", id: "legend"))

    assert_includes node["class"].split, "mt-4"
    assert_equal "legend", node["id"]
  end

  test "outside a container it raises like useChart" do
    assert_raises(ArgumentError) { Chadcn::Chart::Legend::Content.new(payload: payload(:desktop)).call }
  end

  test "with returns a copy with the Legend's alignment" do
    copy = Chadcn::Chart::Legend::Content.new.with(payload: payload(:desktop), vertical_align: :top)
    html = Class.new(Phlex::HTML) { define_method(:view_template) { render(Chadcn::Chart::Container.new(config: CONFIG, id: "l")) { render copy } } }.new.call

    assert_includes box(html)["class"], "pb-3"
  end

  test "payload must be an Array of Hashes" do
    [ "x", { a: 1 }, [ 1 ] ].each do |bad|
      assert_raises(ArgumentError) { Chadcn::Chart::Legend::Content.new(payload: bad) }
    end
    assert_equal "", Chadcn::Chart::Legend::Content.new(payload: nil).call
  end

  test "the generated content helper of a Legend renders the same as the explicit class" do
    items = payload(:desktop)
    helper = Class.new(Chadcn::Chart::Legend) { define_method(:view_template) { content(payload: items, vertical_align: :top) } }
    through_helper = Class.new(Phlex::HTML) do
      define_method(:view_template) { render(Chadcn::Chart::Container.new(config: CONFIG, id: "l")) { render helper.new } }
    end.new.call

    assert_equal render_content(payload: items, vertical_align: :top), through_helper
  end

  test "Legend is a declaration: it renders nothing and keeps the recharts defaults" do
    content = Chadcn::Chart::Legend::Content.new
    legend = Chadcn::Chart::Legend.new(content: content)

    assert_equal "", legend.call
    assert_same content, legend.content_element
    assert_equal [ :bottom, :center, :horizontal, 28, false ], legend.options.values_at(:vertical_align, :align, :layout, :legend_height, :payload_uniq_by)
  end

  test "Legend keeps non-default options and rejects what it cannot use" do
    legend = Chadcn::Chart::Legend.new(vertical_align: "top", width: 200, class: "mt-2")

    assert_equal [ :top, 200, { class: "mt-2" } ], legend.options.values_at(:vertical_align, :width, :attrs)
    assert_raises(ArgumentError) { Chadcn::Chart::Legend.new(vertical_align: :left) }
    assert_raises(ArgumentError) { Chadcn::Chart::Legend.new(content: Chadcn::Chart::Tooltip::Content.new) }
  end

  test "Legend validates align and layout like vertical_align" do
    assert_equal %i[left vertical], Chadcn::Chart::Legend.new(align: "left", layout: :vertical).options.values_at(:align, :layout)
    assert_raises(ArgumentError) { Chadcn::Chart::Legend.new(align: :justify) }
    assert_raises(ArgumentError) { Chadcn::Chart::Legend.new(layout: :grid) }
  end

  test "string-key items and a label that is a component" do
    label = Class.new(Phlex::HTML) { define_method(:view_template) { b { "Rich" } } }.new
    html = render_content(config: { desktop: { label: label } }, payload: [ { "data_key" => "desktop", "color" => "red" } ])

    assert_equal "Rich", box(html).at_css("> div b").text
  end

  test "an entry without a label renders only the dot" do
    node = box(render_content(config: { desktop: { color: "red" } }, payload: payload(:desktop)))

    assert_equal "", node.text
    assert node.at_css("> div > div")
  end

  test "an item without a color writes no style and a false label prints nothing" do
    node = box(render_content(config: { desktop: { label: false } }, payload: [ { data_key: "desktop" } ]))

    assert_nil node.at_css("> div > div")["style"]
    assert_equal "", node.text
  end
end

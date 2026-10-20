# frozen_string_literal: true

require "phlex/test_case"
require "json"

class Phlex::Shadcn::CalendarTest < Phlex::Shadcn::TestCase
  Calendar = Phlex::Shadcn::Calendar

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def calendar(**) = fragment(Calendar.new(today: "2026-03-15", default_month: "2026-03-01", **).call)

  def root(doc) = doc.at_css("[data-slot=calendar]")

  def config(doc) = JSON.parse(root(doc)["data-shadcn--calendar-config-value"])

  # Nokogiri exposes a <template>'s children inside the document: the prototypes are the elements under the template.
  def parts(doc) = doc.css("template[data-shadcn--calendar-target=parts] [data-shadcn--calendar-part]")

  def attrs_of(node, *names) = names.map { |name| node[name] }

  def part(doc, name) = parts(doc).find { |node| node["data-shadcn--calendar-part"] == name }

  def live(doc, selector) = doc.css(selector).reject { |node| node.ancestors("template").any? }

  test "renders the root with its data-slot, lang, controller wiring and the months container with the nav" do
    doc = calendar(mode: :single)

    assert_equal "calendar", root(doc)["data-slot"]
    assert_equal "en-US", root(doc)["lang"]
    assert_equal "single", root(doc)["data-mode"]
    assert_equal "shadcn--calendar", root(doc)["data-controller"]
    months = root(doc).at_css("div.rdp-months")
    nav = months.at_css("nav.rdp-nav")

    assert_equal "Navigation bar", nav["aria-label"]
    assert_equal([ "Go to the Previous Month", "Go to the Next Month" ], nav.css("button").map { |button| button["aria-label"] })
    assert_equal(%w[chevron-left chevron-right], nav.css("svg").map { |svg| svg["class"][/lucide-chevron-[a-z]+/].delete_prefix("lucide-") })
    assert_equal nav, months.element_children.first
  end

  test "root classes keep the shadcn tokens, the rdp class and merge the caller's last" do
    classes = root(calendar(class: "w-full p-0 rounded-lg"))["class"].split

    assert_includes classes, "rdp-root"
    assert_includes classes, "group/calendar"
    assert_includes classes, "bg-background"
    assert_includes classes, "w-full"
    assert_includes classes, "rounded-lg"
    assert_includes classes, 'rtl:**:[.rdp-button\_next>svg]:rotate-180'
    assert_not_includes classes, "w-fit"
    assert_not_includes classes, "p-3"
  end

  test "attrs pass through, data is deep merged, lang and dir are set" do
    doc = calendar(id: "booking", title: "Booking", "aria-label": "Booking calendar", data: { testid: "cal" }, lang: "en-GB", dir: :rtl)

    assert_equal "booking", root(doc)["id"]
    assert_equal "Booking", root(doc)["title"]
    assert_equal "Booking calendar", root(doc)["aria-label"]
    assert_equal "cal", root(doc)["data-testid"]
    assert_equal "en-GB", root(doc)["lang"]
    assert_equal "rtl", root(doc)["dir"]
    assert_equal "calendar", root(doc)["data-slot"]
  end

  test "data attributes follow react-day-picker" do
    plain = root(calendar)
    full = root(calendar(mode: "range", required: false, number_of_months: 2, show_week_number: true))

    assert_not plain.key?("data-mode")
    assert_not plain.key?("data-required")
    assert_not plain.key?("data-multiple-months")
    assert_equal "range", full["data-mode"]
    assert_equal "false", full["data-required"]
    assert_equal "true", full["data-multiple-months"]
    assert_equal "true", full["data-week-numbers"]
  end

  test "string and symbol option values are equivalent" do
    assert_equal calendar(mode: :range, caption_layout: :dropdown_months, button_variant: :outline).to_html,
                 calendar(mode: "range", caption_layout: "dropdown-months", button_variant: "outline").to_html
  end

  test "the nav buttons start disabled when the month cannot move" do
    doc = calendar(start_month: "2026-03-01", end_month: "2026-03-01")
    previous, following = live(doc, "nav button")

    [ previous, following ].each do |button|
      assert_equal "true", button["aria-disabled"]
      assert_equal "-1", button["tabindex"]
      assert button.at_css("svg").key?("disabled")
    end
    open = live(calendar, "nav button")

    assert(open.none? { |button| button.key?("aria-disabled") || button.key?("tabindex") })
    assert(open.none? { |button| button.at_css("svg").key?("disabled") })
  end

  test "the nav starts disabled for disable_navigation, and a year dropdown ends at December of today's year" do
    assert(live(calendar(disable_navigation: true), "nav button").all? { |button| button["aria-disabled"] == "true" })

    last_month = live(calendar(caption_layout: "dropdown", default_month: "2026-12-01"), "nav button")

    assert_not last_month.first.key?("aria-disabled")
    assert_equal "true", last_month.last["aria-disabled"]
  end

  test "hide_navigation renders no nav" do
    assert_empty live(calendar(hide_navigation: true), "nav")
  end

  test "nav button classes use the button variant" do
    outline = live(calendar(button_variant: :outline), "nav button").first["class"].split

    assert_includes outline, "bg-background"
    assert_includes outline, "size-(--cell-size)"
    assert_includes outline, "rdp-button_previous"
    assert_not_includes outline, "h-9"
  end

  test "the controller config carries the initial state as data" do
    cfg = config(calendar(mode: :multiple, selected: [ Date.new(2026, 3, 3), "2026-03-10" ], disabled: [ { day_of_week: [ 0, 6 ] }, Date.new(2026, 3, 12), { before: "2026-03-02", after: "2026-03-20" } ],
                          locale: "es", min: 1, max: 3, required: true))

    assert_equal "multiple", cfg["mode"]
    assert_equal %w[2026-03-03 2026-03-10], cfg["selected"]
    assert_equal "2026-03-15", cfg["today"]
    assert_equal [ { "dayOfWeek" => [ 0, 6 ] }, "2026-03-12", { "before" => "2026-03-02", "after" => "2026-03-20" } ], cfg["disabled"]
    assert_equal "es", cfg["localeKind"]
    assert_equal 1, cfg["weekStartsOn"]
    assert_equal "Ir al mes siguiente", cfg["labels"]["next"]
    assert_equal [ 1, 3, true ], cfg.values_at("min", "max", "required")
  end

  test "range selection, matcher ranges and month normalization" do
    cfg = config(calendar(mode: :range, selected: { from: "2026-03-10" }, default_month: Date.new(2026, 3, 18), disabled: { to: "2026-03-05" },
                          start_month: "2026-01-20"))

    assert_equal({ "from" => "2026-03-10", "to" => nil }, cfg["selected"])
    assert_equal "2026-03-01", cfg["defaultMonth"]
    assert_equal "2026-01-01", cfg["startMonth"]
    assert_equal({ "to" => "2026-03-05", "from" => nil }, cfg["disabled"])
  end

  test "week settings come from the locale, week_starts_on wins" do
    assert_equal [ 0, 1 ], config(calendar).values_at("weekStartsOn", "firstWeekContainsDate")
    assert_equal [ 1, 1 ], config(calendar(locale: :es)).values_at("weekStartsOn", "firstWeekContainsDate")
    assert_equal 6, config(calendar(week_starts_on: "6"))["weekStartsOn"]
    other = config(calendar(locale: "de"))

    assert_nil other["weekStartsOn"]
    assert_equal "other", other["localeKind"]
    assert_equal "ja", config(calendar(locale: "ja"))["locale"]
    assert config(calendar(locale: "ja"))["yearFirst"]
  end

  test "class_names replace the shadcn string of that key and keep the others" do
    doc = calendar(class_names: { weekday: "flex-1 text-xs", day_button: "mine" })

    assert_equal "flex-1 text-xs", part(doc, "weekday")["class"]
    assert_equal "w-full border-collapse rdp-month_grid", part(doc, "month_grid")["class"]
    assert_includes part(doc, "day_button")["class"].split, "mine"
    assert_not_includes part(doc, "day_button")["class"].split, "rdp-day_button"
  end

  test "modifier class strings are not tailwind merged and custom ones come from modifiers_class_names" do
    cfg = config(calendar(modifiers: { booked: [ "2026-03-16" ] }, modifiers_class_names: { booked: "line-through" }))

    assert_equal "rounded-l-md bg-accent rdp-range_start", cfg["dayClasses"]["range_start"]
    assert_equal "text-muted-foreground opacity-50 rdp-disabled", cfg["dayClasses"]["disabled"]
    assert_equal({ "booked" => [ "2026-03-16" ] }, cfg["modifiers"])
    assert_equal({ "booked" => "line-through" }, cfg["modifiersClassNames"])
    assert_includes cfg["dayClasses"]["day"], "[&:first-child[data-selected=true]_button]:rounded-l-md"
    assert_includes config(calendar(show_week_number: true))["dayClasses"]["day"], "[&:nth-child(2)[data-selected=true]_button]:rounded-l-md"
  end

  test "the template holds a prototype of every part the controller builds" do
    doc = calendar(mode: :range, show_week_number: true)
    names = parts(doc).map { |node| node["data-shadcn--calendar-part"] }

    assert_equal %w[caption caption_label day day_button dropdowns month month_grid months_dropdown status week week_number week_number_header weekday weekdays weeks years_dropdown], names.sort
    assert_equal "true", part(doc, "month_grid")["aria-multiselectable"]
    assert_equal "Week Number", part(doc, "week_number_header")["aria-label"]
    assert_equal "[object Object]", part(doc, "week_number")["week"]
    assert_equal "Choose the Month", part(doc, "months_dropdown").at_css("select")["aria-label"]
    assert_equal %w[18 18], attrs_of(part(doc, "years_dropdown").at_css("svg"), "width", "height")
    assert_equal "button", part(doc, "day_button")["type"]
  end

  test "name: renders hidden inputs for each mode" do
    single = live(calendar(mode: :single, selected: "2026-03-10", name: "event[date]"), "input")
    multiple = live(calendar(mode: :multiple, selected: %w[2026-03-03 2026-03-04], name: "days"), "input")
    range = live(calendar(mode: :range, selected: { from: "2026-03-10" }, name: "stay"), "input")

    assert_equal([ [ "event[date]", "2026-03-10" ] ], single.map { |input| [ input["name"], input["value"] ] })
    assert_equal([ [ "days[]", "" ], [ "days[]", "2026-03-03" ], [ "days[]", "2026-03-04" ] ], multiple.map { |input| [ input["name"], input["value"] ] })
    assert_equal([ [ "stay[from]", "2026-03-10" ], [ "stay[to]", "" ] ], range.map { |input| [ input["name"], input["value"] ] })
    assert(single.all? { |input| input["type"] == "hidden" })
  end

  test "footer renders a status region after the months" do
    footer = live(calendar(footer: "Pick a day."), ".rdp-footer").first

    assert_equal "status", footer["role"]
    assert_equal "polite", footer["aria-live"]
    assert_equal "Pick a day.", footer.text
  end

  test "port-only form options reach the controller" do
    cfg = config(calendar(mode: :single, input: "#date", label: "#date-label", close_on_select: true))

    assert_equal [ "#date", "#date-label", true ], cfg.values_at("input", "label", "closeOnSelect")
    assert_equal({ "from" => "#a", "to" => "#b" }, config(calendar(mode: :range, input: { from: "#a", to: "#b" }))["input"])
  end

  test "formatters take Intl option hashes" do
    cfg = config(calendar(formatters: { format_caption: { month: :short, year: "numeric", locale: "fr" } }))

    assert_equal({ "formatCaption" => { "month" => "short", "year" => "numeric", "locale" => "fr" } }, cfg["formatters"])
  end

  test "the month kwarg is the controlled month value" do
    doc = calendar(month: "2026-05-17")

    assert_equal "2026-05-01", root(doc)["data-shadcn--calendar-month-value"]
    assert_not root(calendar).key?("data-shadcn--calendar-month-value")
  end

  test "invalid options raise ArgumentError" do
    [
      { mode: :both }, { caption_layout: :tabs }, { button_variant: :nope }, { dir: :up }, { number_of_months: 0 }, { week_starts_on: 7 },
      { components: { Day: 1 } }, { today: "15/03/2026" }, { today: "2026-02-30" }, { mode: :single, selected: [ "2026-03-10" ] },
      { mode: :multiple, selected: "2026-03-10" }, { mode: :range, selected: "2026-03-10" }, { disabled: ->(_) { true } },
      { disabled: { weekday: 1 } }, { class_names: { nope: "x" } }, { formatters: { format_caption: ->(_) { "x" } } },
      { formatters: { format_nothing: {} } }, { locale: "not a tag" }, { input: 4 }, { min: -1 }, { modifiers: { x: Object.new } }
    ].each do |options|
      assert_raises(ArgumentError, options.inspect) { calendar(**options) }
    end
  end

  test "input: hashes need mode range and exactly from and to selectors; selected: and name: need a mode" do
    assert_raises(ArgumentError) { calendar(mode: :single, input: { from: "#a", to: "#b" }) }
    assert_raises(ArgumentError) { calendar(mode: :range, input: { from: "#a" }) }
    assert_raises(ArgumentError) { calendar(mode: :range, input: { from: "#a", to: "#b", extra: "#c" }) }
    assert_raises(ArgumentError) { calendar(mode: :range, input: { from: "#a", to: 1 }) }
    assert_raises(ArgumentError) { calendar(selected: "2026-03-10") }
    assert_raises(ArgumentError) { calendar(name: "day") }
  end

  test "components: {} is accepted" do
    assert_equal "calendar", root(calendar(components: {}))["data-slot"]
  end

  test "a block is ignored" do
    assert_equal calendar.to_html, fragment(Calendar.new(today: "2026-03-15", default_month: "2026-03-01").call { "ignored" }).to_html
  end

  test "Calendar::DayButton renders the ghost icon button with the tsx data attributes" do
    html = Calendar::DayButton.new(day: Date.new(2026, 3, 5), modifiers: { selected: true, range_start: false, range_end: false, range_middle: true }).call { "5" }
    button = fragment(html).at_css("button")

    assert_equal %w[button ghost icon], attrs_of(button, "data-slot", "data-variant", "data-size")
    assert_equal "3/5/2026", button["data-day"]
    assert_equal "false", button["data-selected-single"]
    assert_equal %w[false false true], attrs_of(button, "data-range-start", "data-range-end", "data-range-middle")
    assert_not button.key?("type")
    assert_equal "5", button.text
    assert_includes button["class"].split, "rdp-day"
    assert_includes button["class"].split, "min-w-(--cell-size)"
    assert_not_includes button["class"].split, "inline-flex"
  end

  test "Calendar::DayButton data attributes follow the modifiers present" do
    plain = fragment(Calendar::DayButton.new(day: { date: "2026-03-05" }).call).at_css("button")
    off = fragment(Calendar::DayButton.new(day: "2026-03-05", modifiers: { "selected" => false }).call).at_css("button")
    on = fragment(Calendar::DayButton.new(day: "2026-03-05", modifiers: { selected: true }).call).at_css("button")

    assert_equal([ false, false, false, false ], %w[data-selected-single data-range-start data-range-end data-range-middle].map { |name| plain.key?(name) })
    assert_equal "false", off["data-selected-single"]
    assert_equal "true", on["data-selected-single"]
    assert_not on.key?("data-range-start")
  end

  test "Calendar::DayButton merges class, passes attrs and rejects non-dates" do
    button = fragment(Calendar::DayButton.new(day: "2026-03-05", class: "rounded-full", "aria-label": "Fifth", tabindex: -1,
                                              disabled: true).call).at_css("button")

    assert_includes button["class"].split, "rounded-full"
    assert_equal "Fifth", button["aria-label"]
    assert_equal "-1", button["tabindex"]
    assert button.key?("disabled")
    assert_raises(ArgumentError) { Calendar::DayButton.new(day: "soon") }
    assert_raises(ArgumentError) { Calendar::DayButton.new(day: nil) }
  end

  test "the generated day_button helper renders the same HTML as the class" do
    explicit = Class.new(Phlex::HTML) { define_method(:view_template) { render Calendar::DayButton.new(day: "2026-03-05") { "5" } } }.new.call
    helper = Class.new(Calendar) { define_method(:view_template) { day_button(day: "2026-03-05") { "5" } } }.new.call

    assert_equal explicit, helper
  end
end

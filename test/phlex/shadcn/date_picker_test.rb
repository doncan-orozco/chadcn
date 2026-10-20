# frozen_string_literal: true

require "phlex/test_case"
require "json"

# The DatePicker is not a class: it is the Popover + Button + Calendar composition documented in docs/form-controls.md. This renders
# that composition and checks the wiring the controller relies on (the hidden input outside the popover, the label, the options).
class Phlex::Shadcn::DatePickerTest < Phlex::Shadcn::TestCase
  Popover = Phlex::Shadcn::Popover
  Calendar = Phlex::Shadcn::Calendar

  # The composition of the docs, as a form field named `event[date]`.
  def ordinal(day) = (11..13).cover?(day % 100) ? "th" : { 1 => "st", 2 => "nd", 3 => "rd" }.fetch(day % 10, "th")

  def date_picker(date: nil, **calendar)
    suffix = date && ordinal(date.day)
    Class.new(Phlex::HTML) do
      define_method(:view_template) do
        form(action: "/events", method: "post") do
          input(type: "hidden", id: "event_date", name: "event[date]", value: date&.iso8601)
          render Popover.new do
            render Popover::Trigger.new(as_child: Phlex::Shadcn::Button.new(variant: "outline", class: "w-[240px] justify-start text-left font-normal")) do
              render Phlex::Shadcn::Icon.new("calendar")
              span(id: "event_date_label", data: { shadcn__calendar_placeholder: "Pick a date", empty: date.nil?.to_s }) do
                date ? date.strftime("%B #{date.day}#{suffix}, %Y") : "Pick a date"
              end
            end
            render Popover::Content.new(class: "w-auto p-0", align: "start") do
              render Calendar.new(mode: :single, input: "#event_date", label: "#event_date_label", close_on_select: true, **calendar)
            end
          end
        end
      end
    end.new.call
  end

  def doc(html) = Nokogiri::HTML5.fragment(html)

  # What a browser would submit for the form: name => value of every named input outside a template.
  def submission(fragment)
    fragment.css("form input[name]").reject { |input| input.ancestors("template").any? }.to_h { |input| [ input["name"], input["value"].to_s ] }
  end

  test "the form input lives outside the popover content and submits the ISO date" do
    fragment = doc(date_picker(date: Date.new(2026, 3, 10)))
    input = fragment.at_css("input#event_date")

    assert_equal "hidden", input["type"]
    assert_empty input.ancestors("template")
    assert_equal({ "event[date]" => "2026-03-10" }, submission(fragment))
  end

  test "an empty date submits an empty value" do
    assert_equal({ "event[date]" => "" }, submission(doc(date_picker)))
  end

  test "the calendar sits inside the popover content template and is wired to the input and the label" do
    fragment = doc(date_picker(date: Date.new(2026, 3, 10)))
    calendar = fragment.at_css("template [data-slot=calendar]")
    config = JSON.parse(calendar["data-shadcn--calendar-config-value"])

    assert_predicate calendar.ancestors("template"), :any?
    assert_equal "single", config["mode"]
    assert_equal "#event_date", config["input"]
    assert_equal "#event_date_label", config["label"]
    assert config["closeOnSelect"]
    label = fragment.at_css("#event_date_label")

    assert_equal "March 10th, 2026", label.text
    assert_equal "Pick a date", label["data-shadcn--calendar-placeholder"]
    assert_equal "false", label["data-empty"]
  end

  test "an empty picker renders the placeholder text with data-empty true; ordinals follow date-fns" do
    label = doc(date_picker).at_css("#event_date_label")

    assert_equal [ "Pick a date", "Pick a date", "true" ], [ label.text, label["data-shadcn--calendar-placeholder"], label["data-empty"] ]
    suffixes = [ 1, 2, 3, 4, 11, 12, 13, 21, 22, 23, 31 ].map { |day| ordinal(day) }

    assert_equal %w[st nd rd th th th th st nd rd st], suffixes
  end

  test "the trigger is a button with the calendar icon and the label span" do
    fragment = doc(date_picker)
    trigger = fragment.at_css("[data-slot=popover-trigger]")

    assert_equal "button", trigger.name
    assert_equal "outline", trigger["data-variant"]
    assert trigger.at_css("svg.lucide-calendar")
    assert_equal "Pick a date", trigger.at_css("#event_date_label").text
  end

  test "range pickers take a selector per input and a multiple picker none" do
    range = Calendar.new(mode: :range, input: { from: "#from", to: "#to" }).call
    config = JSON.parse(doc(range).at_css("[data-slot=calendar]")["data-shadcn--calendar-config-value"])

    assert_equal({ "from" => "#from", "to" => "#to" }, config["input"])
    assert_equal "multiple", JSON.parse(doc(Calendar.new(mode: :multiple).call).at_css("[data-slot=calendar]")["data-shadcn--calendar-config-value"])["mode"]
  end
end

# frozen_string_literal: true

# The part prototypes of a Calendar: one inert `<template>` whose elements carry the FINAL class strings of every part the controller
# builds (months, captions, dropdowns, the grid, week numbers, day cells and buttons). The controller clones them, so no Tailwind token
# ever appears in JavaScript. Mixed into {Chadcn::Calendar}; needs its `@classes`, `@options` and `cn`.
#
# @api private
module Chadcn::Calendar::Parts
  # Visually hidden live region that announces the caption in the dropdown layouts (rdp `DP:282-293`).
  VISUALLY_HIDDEN = "border:0;clip:rect(0 0 0 0);height:1px;margin:-1px;overflow:hidden;padding:0;position:absolute;width:1px;white-space:nowrap;word-wrap:normal"

  # Wrapper of the week number (the shadcn `WeekNumber` override).
  WEEK_NUMBER_BOX = "flex size-(--cell-size) items-center justify-center text-center"

  # Placeholder day of the day button prototype; the controller overwrites everything that depends on the day.
  PLACEHOLDER_DAY = "2000-01-01"

  # Size of the chevron inside a dropdown (rdp `Dropdown` passes `size: 18`).
  DROPDOWN_CHEVRON_SIZE = 18

  private

  def parts_template
    template(data: { chadcn__calendar_target: "parts" }) do
      part(:month, :div, class: @classes[:month])
      part(:caption, :div, class: @classes[:month_caption])
      part(:caption_label, :span, class: @classes[:caption_label], role: "status", aria: { live: "polite" })
      part(:dropdowns, :div, class: @classes[:dropdowns])
      dropdown_part(:months_dropdown, "monthDropdown")
      dropdown_part(:years_dropdown, "yearDropdown")
      part(:status, :span, role: "status", aria: { live: "polite" }, style: VISUALLY_HIDDEN)
      part(:month_grid, :table, class: @classes[:month_grid], role: "grid", aria: { multiselectable: %w[multiple range].include?(@options.mode).to_s })
      table_parts
      render Chadcn::Calendar::DayButton.new(day: PLACEHOLDER_DAY, type: "button", class: @classes[:day_button],
                                             data: { chadcn__calendar_part: "day_button" })
    end
  end

  # Table parts live inside one `table`: the HTML parser drops `thead`, `tr`, `th` and `td` start tags that do not follow a table
  # context, so they cannot sit beside the `div`s of the other prototypes in a `template`.
  def table_parts
    table do
      thead(aria: { hidden: "true" }, data: { chadcn__calendar_part: "weekdays" }) { tr(class: @classes[:weekdays]) }
      tbody(class: @classes[:weeks], data: { chadcn__calendar_part: "weeks" })
      tbody do
        tr(class: @classes[:week], data: { chadcn__calendar_part: "week" })
        tr do
          part(:week_number_header, :th, class: @classes[:week_number_header], scope: "col", aria: { label: labels["weekNumberHeader"] })
          part(:weekday, :th, class: @classes[:weekday], scope: "col")
          # `week` is rdp's week object spread onto the td by the shadcn override; React stringifies it, and the oracle DOM has it.
          part(:week_number, :td, week: "[object Object]", class: @classes[:week_number], scope: "row", role: "rowheader") { div(class: WEEK_NUMBER_BOX) }
          part(:day, :td, role: "gridcell")
        end
      end
    end
  end

  # rdp `Dropdown` (DD:15-19): the root span, the native select and the aria-hidden caption with the chevron.
  def dropdown_part(key, label_key)
    part(key, :span, class: @classes[:dropdown_root], data: { disabled: @options.disable_navigation?.to_s }) do
      tag(:select, class: [ @classes[:dropdown], @classes[key] ].join(" "), aria: { label: labels[label_key] },
                   disabled: (true if @options.disable_navigation?))
      span(class: @classes[:caption_label], aria: { hidden: "true" }) do
        render Chadcn::Icon.new("chevron-down", width: DROPDOWN_CHEVRON_SIZE, height: DROPDOWN_CHEVRON_SIZE,
                                                class: cn("size-4", @classes[:chevron]))
      end
    end
  end

  # The class strings are final (they already went through `cn`, or are a caller override that React keeps verbatim), so the attributes
  # are not merged again.
  def part(name, element, data: nil, **attrs, &)
    tag(element, data: { chadcn__calendar_part: name.to_s }.merge(data || {}), **attrs, &)
  end

  def labels = @options.locale.labels
end

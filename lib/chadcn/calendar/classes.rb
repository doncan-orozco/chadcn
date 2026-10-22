# frozen_string_literal: true

# Class strings of the Calendar parts: the shadcn `classNames` of calendar.tsx joined with react-day-picker's default class names
# (`getDefaultClassNames()`, which the tsx appends to every key). Every Tailwind token of the calendar lives in this file and in
# {Chadcn::Calendar}; the Stimulus controller only receives the finished strings.
#
# @api private
module Chadcn::Calendar::Classes
  # rdp `getDefaultClassNames()` (GDC:11-30): UI key => its `rdp-*` class.
  RDP = {
    root: "rdp-root", months: "rdp-months", month: "rdp-month", nav: "rdp-nav", button_previous: "rdp-button_previous",
    button_next: "rdp-button_next", month_caption: "rdp-month_caption", dropdowns: "rdp-dropdowns", dropdown_root: "rdp-dropdown_root",
    dropdown: "rdp-dropdown", months_dropdown: "rdp-months_dropdown", years_dropdown: "rdp-years_dropdown", caption_label: "rdp-caption_label",
    chevron: "rdp-chevron", month_grid: "rdp-month_grid", weekdays: "rdp-weekdays", weekday: "rdp-weekday", weeks: "rdp-weeks",
    week: "rdp-week", week_number_header: "rdp-week_number_header", week_number: "rdp-week_number", day: "rdp-day",
    day_button: "rdp-day_button", footer: "rdp-footer", focused: "rdp-focused", selected: "rdp-selected", disabled: "rdp-disabled",
    hidden: "rdp-hidden", outside: "rdp-outside", today: "rdp-today", range_start: "rdp-range_start", range_middle: "rdp-range_middle",
    range_end: "rdp-range_end"
  }.freeze

  # Keys a caller may pass in `class_names:` (rdp `UI` and `DayFlag`/`SelectionState` keys).
  KEYS = RDP.keys.freeze

  # The modifier keys whose class string lands on a day cell, in the order rdp emits them (focused, disabled, hidden, outside, today,
  # custom modifiers, then selected and the range flags).
  DAY_FLAGS = %i[focused disabled hidden outside today selected range_start range_end range_middle].freeze

  # Mirrors the `buttonVariants` utilities the tsx adds to both nav buttons.
  NAV_BUTTON = "size-(--cell-size) p-0 select-none aria-disabled:opacity-50"

  # Caption label of the dropdown layouts (the label layout is `text-sm`).
  DROPDOWN_CAPTION = "flex h-8 items-center gap-1 rounded-md pr-1 pl-2 text-sm [&>svg]:size-3.5 [&>svg]:text-muted-foreground"

  # Day cell classes that depend on `show_week_number` (the rounded corner of a selected cell is the first or the second child).
  DAY_FIRST_CHILD = "[&:first-child[data-selected=true]_button]:rounded-l-md"
  # Same as {DAY_FIRST_CHILD} when the week number takes the first cell.
  DAY_SECOND_CHILD = "[&:nth-child(2)[data-selected=true]_button]:rounded-l-md"

  module_function

  # The class string of every key.
  #
  # @param caption_layout [String] `label`, `dropdown`, `dropdown-months` or `dropdown-years`
  # @param show_week_number [Boolean]
  # @param button_variant [String] a Button variant
  # @param overrides [Hash{Symbol => String}] the caller's `class_names:`; a given key replaces the whole string of that key
  # @param merger [#call] the `cn` of the rendering component
  # @return [Hash{Symbol => String}]
  def build(caption_layout:, show_week_number:, button_variant:, overrides:, merger:)
    nav_button = [ Chadcn::Button.variants(variant: button_variant), NAV_BUTTON ]
    shadcn = {
      root: "w-fit",
      months: "relative flex flex-col gap-4 md:flex-row",
      month: "flex w-full flex-col gap-4",
      nav: "absolute inset-x-0 top-0 flex w-full items-center justify-between gap-1",
      button_previous: nav_button,
      button_next: nav_button,
      month_caption: "flex h-(--cell-size) w-full items-center justify-center px-(--cell-size)",
      dropdowns: "flex h-(--cell-size) w-full items-center justify-center gap-1.5 text-sm font-medium",
      dropdown_root: "relative rounded-md border border-input shadow-xs has-focus:border-ring has-focus:ring-[3px] has-focus:ring-ring/50",
      dropdown: "absolute inset-0 bg-popover opacity-0",
      caption_label: [ "font-medium select-none", caption_layout == "label" ? "text-sm" : DROPDOWN_CAPTION ],
      month_grid: "w-full border-collapse",
      weekdays: "flex",
      weekday: "flex-1 rounded-md text-[0.8rem] font-normal text-muted-foreground select-none",
      week: "mt-2 flex w-full",
      week_number_header: "w-(--cell-size) select-none",
      week_number: "text-[0.8rem] text-muted-foreground select-none",
      day: [ "group/day relative aspect-square h-full w-full p-0 text-center select-none [&:last-child[data-selected=true]_button]:rounded-r-md",
             show_week_number ? DAY_SECOND_CHILD : DAY_FIRST_CHILD ],
      range_start: "rounded-l-md bg-accent",
      range_middle: "rounded-none",
      range_end: "rounded-r-md bg-accent",
      today: "rounded-md bg-accent text-accent-foreground data-[selected=true]:rounded-none",
      outside: "text-muted-foreground aria-selected:text-muted-foreground",
      disabled: "text-muted-foreground opacity-50",
      hidden: "invisible"
    }
    RDP.to_h do |key, rdp|
      [ key, overrides.key?(key) ? overrides[key].to_s : merger.call(shadcn[key], rdp) ]
    end
  end
end

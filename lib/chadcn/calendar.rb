# frozen_string_literal: true

# shadcn `Calendar` (new-york-v4), which wraps react-day-picker 10. Spec: docs/shadcn-port/specs/calendar.md.
# Behavior: controllers/shadcn/calendar_controller.js, on `Date` and `Intl` only (no date library).
#
# The server renders the root, the months container with its navigation, the optional footer and hidden inputs, and one inert
# `<template>` of part prototypes holding every class string; the Stimulus controller builds the months and the grid from them.
# Without JavaScript only the shell and the navigation exist.
#
# @example A single-date calendar
#   render Chadcn::Calendar.new(mode: :single, selected: Date.new(2026, 3, 15))
# @example A range over two months, Monday first
#   render Chadcn::Calendar.new(mode: :range, number_of_months: 2, week_starts_on: 1,
#                                      selected: { from: Date.new(2026, 3, 10), to: Date.new(2026, 3, 14) })
# @example Disabled days and a custom modifier
#   render Chadcn::Calendar.new(mode: :single, disabled: [ { day_of_week: [ 0, 6 ] }, { before: Date.today } ],
#                                      modifiers: { booked: [ Date.new(2026, 3, 16) ] }, modifiers_class_names: { booked: "line-through" })
#
# Events (bubbling, on the root): `shadcn--calendar:select` with `detail: { selected, date, modifiers }` and
# `shadcn--calendar:month-change` with `detail: { month }`. See {file:docs/form-controls.md} for the date picker composition
# (Popover + Button + Calendar + hidden input).
#
# The nested {DayButton} is the shadcn `CalendarDayButton`; the controller clones a prototype of it for every day.
class Chadcn::Calendar < Chadcn::Base
  include Chadcn::Calendar::Parts

  # Tailwind classes of the root (calendar.tsx `className`), before the caller's.
  #
  # @api private
  ROOT_CLASSES = "group/calendar bg-background p-3 [--cell-size:--spacing(8)] [[data-slot=card-content]_&]:bg-transparent [[data-slot=popover-content]_&]:bg-transparent"

  # Flips the chevrons in right-to-left text (calendar.tsx `String.raw`); the backslash is part of the class.
  #
  # @api private
  RTL_CLASSES = [ 'rtl:**:[.rdp-button\_next>svg]:rotate-180', 'rtl:**:[.rdp-button\_previous>svg]:rotate-180' ].freeze

  # @param mode [String, Symbol, nil] `single`, `multiple`, `range` or nil (a non-interactive grid)
  # @param selected [Date, Time, String, Array, Hash, nil] the initial selection: a date (single), an Array of dates (multiple) or
  #   `{ from:, to: }` (range); dates are `Date`, `Time` or `YYYY-MM-DD` strings
  # @param default_month [Date, Time, String, nil] first displayed month (uncontrolled)
  # @param month [Date, Time, String, nil] controlled first displayed month; the caller moves it by setting the
  #   `data-shadcn--calendar-month-value` attribute
  # @param today [Date, Time, String, nil] the day highlighted as today; nil uses the browser's date
  # @param number_of_months [Integer] months shown side by side
  # @param show_outside_days [Boolean] show the days of the neighbouring months
  # @param caption_layout [String, Symbol] `label`, `dropdown`, `dropdown-months` or `dropdown-years` (`:dropdown_months` works too)
  # @param button_variant [String, Symbol] Button variant of the navigation buttons
  # @param locale [String, Symbol, nil] BCP 47 tag; exact for nil/`en`/`en-US` and `es`, `Intl` approximations for other tags
  # @param week_starts_on [Integer, String, nil] 0..6 (0 = Sunday); nil takes it from the locale
  # @param fixed_weeks [Boolean] always show six weeks per month
  # @param show_week_number [Boolean] add a week number column
  # @param disabled [Object] matcher(s): true, a date, an Array of dates, `{ from:, to: }`, `{ day_of_week: }`, `{ before:, after: }`,
  #   `{ after: }`, `{ before: }` or an Array mixing them
  # @param hidden [Object] matcher(s), like `disabled`
  # @param modifiers [Hash{Symbol, String => Object}] custom modifier name => matcher(s)
  # @param modifiers_class_names [Hash{Symbol, String => String}] custom modifier name => classes
  # @param class_names [Hash{Symbol => String}] rdp UI key (`day`, `weekday`, `today`...) => classes; replaces the shadcn string of that key
  # @param formatters [Hash{Symbol => Hash}] `format_caption`, `format_day`, `format_month_dropdown`, `format_weekday_name` or
  #   `format_year_dropdown` => `Intl.DateTimeFormat` options (plus an optional `locale:`)
  # @param components [nil, Hash] only nil or an empty Hash (render overrides are not portable)
  # @param start_month [Date, Time, String, nil] first month that can be navigated to
  # @param end_month [Date, Time, String, nil] last month that can be navigated to
  # @param min [Integer, nil] multiple: minimum days; range: minimum nights
  # @param max [Integer, nil] multiple: maximum days; range: maximum nights
  # @param required [Boolean, nil] whether the selection cannot be cleared (nil: not set)
  # @param exclude_disabled [Boolean] range only: a range containing a disabled day restarts
  # @param reset_on_select [Boolean] range only: a click on a complete range starts a new one
  # @param disable_navigation [Boolean] turn the month navigation off
  # @param hide_navigation [Boolean] do not render the previous/next buttons
  # @param hide_weekdays [Boolean] do not render the weekday header
  # @param paged_navigation [Boolean] the buttons move by `number_of_months`
  # @param auto_focus [Boolean] focus the day target on connect
  # @param footer [String, nil] text below the months
  # @param dir [String, Symbol, nil] `ltr` or `rtl`; with `rtl` the horizontal arrow keys are reversed
  # @param name [String, nil] render hidden inputs named like this inside the root (single `name`, multiple `name[]`, range `name[from]`/`name[to]`)
  # @param input [String, Hash, nil] CSS selector of an external hidden input (or `{ from:, to: }` selectors) that is the source of truth
  #   and receives the selection; used by the date picker composition
  # @param label [String, nil] CSS selector of an element whose text shows the formatted selection (its initial text is the placeholder)
  # @param close_on_select [Boolean] close the enclosing Popover after a completing selection
  # @param attrs [Hash] HTML attributes of the root (`id:`, `lang:`, `aria-label:`, `data:`, `class:` merged last)
  # @raise [ArgumentError] for an unknown option value, a selection that does not fit the mode, or a value that cannot reach the browser as data
  def initialize(mode: nil, selected: nil, default_month: nil, month: nil, today: nil, number_of_months: 1, show_outside_days: true,
                 caption_layout: "label", button_variant: "ghost", locale: nil, week_starts_on: nil, fixed_weeks: false,
                 show_week_number: false, disabled: nil, hidden: nil, modifiers: nil, modifiers_class_names: nil, class_names: nil,
                 formatters: nil, components: nil, start_month: nil, end_month: nil, min: nil, max: nil, required: nil,
                 exclude_disabled: false, reset_on_select: false, disable_navigation: false, hide_navigation: false,
                 hide_weekdays: false, paged_navigation: false, auto_focus: false, footer: nil, dir: nil, name: nil, input: nil,
                 label: nil, close_on_select: false, **attrs)
    @options = Chadcn::Calendar::Options.new(
      mode:, selected:, default_month:, month:, today:, number_of_months:, show_outside_days:, caption_layout:, button_variant:, locale:,
      week_starts_on:, fixed_weeks:, show_week_number:, disabled:, hidden:, modifiers:, modifiers_class_names:, class_names:, formatters:,
      components:, start_month:, end_month:, min:, max:, required:, exclude_disabled:, reset_on_select:, disable_navigation:,
      hide_navigation:, hide_weekdays:, paged_navigation:, auto_focus:, footer:, dir:, name:, input:, label:, close_on_select:
    )
    @attrs = attrs
    super()
  end

  # Renders the root with the months container, footer, hidden inputs and the prototype template. A block is ignored.
  #
  # @return [void]
  def view_template
    @classes = Chadcn::Calendar::Classes.build(
      caption_layout: @options.caption_layout, show_week_number: @options.show_week_number, button_variant: @options.button_variant,
      overrides: @options.class_names, merger: method(:cn)
    )
    div(**root_attrs) do
      div(class: @classes[:months], data: { shadcn__calendar_target: "months" }) { navigation unless @options.hide_navigation }
      footer_element if @options.footer
      hidden_inputs if @options.name
      parts_template
    end
  end

  private

  def root_attrs
    attrs = merge_attrs({ lang: @options.locale.lang, dir: @options.dir, data: root_data }, @attrs.except(:class))
    attrs.merge(class: cn(@classes[:root], cn(ROOT_CLASSES, *RTL_CLASSES, @attrs[:class])))
  end

  # rdp getDataAttributes plus the Stimulus wiring.
  def root_data
    {
      slot: "calendar", mode: @options.mode, required: @options.required, multiple_months: (true if @options.multiple_months?),
      week_numbers: (true if @options.show_week_number), controller: "shadcn--calendar",
      shadcn__calendar_config_value: json(@options.config(@classes)), shadcn__calendar_month_value: @options.month
    }
  end

  def navigation
    state = @options.navigation
    nav(class: @classes[:nav], aria: { label: labels["nav"] }, data: { shadcn__calendar_target: "nav" }) do
      nav_button(:previous, "chevron-left", state[:previous])
      nav_button(:next, "chevron-right", state[:next])
    end
  end

  def nav_button(direction, icon, enabled)
    button(type: "button", class: @classes[:"button_#{direction}"], aria: { label: labels[direction.to_s], disabled: ("true" unless enabled) },
           tabindex: (-1 unless enabled), data: { shadcn__calendar_target: direction.to_s, action: "click->shadcn--calendar##{direction}" }) do
      render Chadcn::Icon.new(icon, class: cn("size-4", @classes[:chevron]), disabled: (true unless enabled))
    end
  end

  def footer_element
    div(class: @classes[:footer], role: "status", aria: { live: "polite" }) { plain @options.footer }
  end

  # Hidden inputs of `name:`, kept in sync by the controller (`data-shadcn--calendar-field` tells it what each one holds).
  def hidden_inputs
    case @options.mode
    when "multiple"
      hidden_input("#{@options.name}[]", "", "blank")
      Array(@options.selected).each { |date| hidden_input("#{@options.name}[]", date, "item") }
    when "range"
      hidden_input("#{@options.name}[from]", @options.selected&.fetch("from"), "from")
      hidden_input("#{@options.name}[to]", @options.selected&.fetch("to"), "to")
    else hidden_input(@options.name, @options.selected, "single")
    end
  end

  def hidden_input(name, value, field)
    input(type: "hidden", name:, value: value.to_s, data: { shadcn__calendar_field: field })
  end
end

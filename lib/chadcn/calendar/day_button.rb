# frozen_string_literal: true

# shadcn `CalendarDayButton` (new-york-v4): the ghost icon `Button` of one day. {Chadcn::Calendar} renders a prototype of it
# and its controller clones one per day; rendered on its own it is a plain server-rendered button.
#
# Differences from React when rendered outside a Calendar (spec calendar.md, "Calendar::DayButton"): `data-day` is the en-US
# `M/D/YYYY` form (the server cannot know the browser locale) and `modifiers: { focused: true }` does not focus the button.
#
# @example
#   render Chadcn::Calendar::DayButton.new(day: "2026-03-15", modifiers: { selected: true }) { "15" }
class Chadcn::Calendar::DayButton < Chadcn::Base
  # Tailwind classes of the day button (calendar.tsx `CalendarDayButton`).
  #
  # @api private
  CLASSES = "flex aspect-square size-auto w-full min-w-(--cell-size) flex-col gap-1 leading-none font-normal group-data-[focused=true]/day:relative group-data-[focused=true]/day:z-10 group-data-[focused=true]/day:border-ring group-data-[focused=true]/day:ring-[3px] group-data-[focused=true]/day:ring-ring/50 data-[range-end=true]:rounded-md data-[range-end=true]:rounded-r-md data-[range-end=true]:bg-primary data-[range-end=true]:text-primary-foreground data-[range-middle=true]:rounded-none data-[range-middle=true]:bg-accent data-[range-middle=true]:text-accent-foreground data-[range-start=true]:rounded-md data-[range-start=true]:rounded-l-md data-[range-start=true]:bg-primary data-[range-start=true]:text-primary-foreground data-[selected-single=true]:bg-primary data-[selected-single=true]:text-primary-foreground dark:hover:text-accent-foreground [&>span]:text-xs [&>span]:opacity-70"

  # rdp's default `day` class, which the tsx merges into the button (`defaultClassNames.day`).
  #
  # @api private
  RDP_DAY = "rdp-day"

  # Default of `modifiers:` (no modifier).
  #
  # @api private
  NO_MODIFIERS = {}.freeze

  # @param day [Date, Time, String, Hash] the day: a date, an ISO `YYYY-MM-DD` string, or a Hash with a `:date` key (rdp's `CalendarDay`)
  # @param modifiers [Hash] rdp day modifiers (`selected`, `range_start`, `range_end`, `range_middle`, `focused`, `today`, `outside`,
  #   `disabled`, `hidden`), String or Symbol keys. `data-selected-single` and `data-range-*` derive from the first four.
  # @param attrs [Hash] HTML attributes merged onto the button (`aria-label:`, `tabindex:`, `disabled:`, `class:`...)
  # @raise [ArgumentError] when `day` is not a date
  def initialize(day:, modifiers: NO_MODIFIERS, **attrs)
    date = day.is_a?(Hash) ? (day[:date] || day["date"]) : day
    @date = Chadcn::Calendar::Dates.to_date(date, "day")
    @modifiers = modifiers.transform_keys(&:to_s)
    @attrs = attrs
    super()
  end

  # @yield the label of the day (usually its number)
  # @return [void]
  def view_template(&)
    render Chadcn::Button.new(variant: "ghost", size: "icon", **merge_attrs(default_attrs, @attrs.except(:class)),
                              class: cn(CLASSES, RDP_DAY, @attrs[:class])), &
  end

  private

  def default_attrs
    day = "#{@date.month}/#{@date.day}/#{@date.year}"
    {
      data: {
        day: day,
        selected_single: selected_single,
        range_start: flag("range_start"),
        range_end: flag("range_end"),
        range_middle: flag("range_middle")
      }
    }
  end

  # The JS `modifiers.selected && !range_start && !range_end && !range_middle` of the tsx: absent for an absent/nil `selected`, "false"
  # for `selected: false`, else a boolean string.
  def selected_single
    selected = @modifiers["selected"]
    return selected if selected.nil? || selected == false

    %w[range_start range_end range_middle].none? { |key| @modifiers[key] }
  end

  # React renders `data-range-start={modifiers.range_start}`: the string for a boolean, nothing for an absent key.
  def flag(key) = @modifiers[key]
end

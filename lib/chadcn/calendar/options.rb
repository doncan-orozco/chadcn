# frozen_string_literal: true

# The validated, normalized options of a {Chadcn::Calendar}: coerces dates to ISO strings, matchers to their JSON form and
# checks every enumerated value, then answers the two questions the server needs (the controller config, and which nav buttons start
# disabled). Raises `ArgumentError` for anything that cannot reach the controller as data.
#
# @api private
class Chadcn::Calendar::Options
  # Accepted values of `mode:`.
  MODES = %w[single multiple range].freeze
  # Accepted values of `caption_layout:`.
  CAPTION_LAYOUTS = %w[label dropdown dropdown-months dropdown-years].freeze
  # Accepted values of `dir:`.
  DIRS = %w[ltr rtl].freeze
  # `formatters:` keys, the rdp formatters that can be expressed as `Intl.DateTimeFormat` options.
  FORMATTERS = %w[format_caption format_day format_month_dropdown format_weekday_name format_year_dropdown].freeze

  # @return [String, nil] `single`, `multiple`, `range` or nil (a non-interactive grid)
  attr_reader :mode
  # @return [Chadcn::Calendar::Locale]
  attr_reader :locale
  # @return [String] `label`, `dropdown`, `dropdown-months` or `dropdown-years`
  attr_reader :caption_layout
  # @return [String] a Button variant
  attr_reader :button_variant
  # @return [Hash{Symbol => String}] the caller's `class_names:` (symbol keys, validated)
  attr_reader :class_names
  # @return [Boolean]
  attr_reader :show_week_number
  # @return [Boolean]
  attr_reader :hide_navigation
  # @return [String, nil]
  attr_reader :footer
  # @return [String, nil]
  attr_reader :dir
  # @return [String, nil]
  attr_reader :name
  # @return [Boolean, nil]
  attr_reader :required
  # @return [String, nil] the ISO month (`YYYY-MM-01`) of the controlled `month:`
  attr_reader :month
  # @return [Object] the normalized selection (a date, an Array of dates, a `from`/`to` Hash or nil)
  attr_reader :selected

  # Arguments are those of {Chadcn::Calendar#initialize}.
  def initialize(mode:, selected:, default_month:, month:, today:, number_of_months:, show_outside_days:, caption_layout:, button_variant:,
                 locale:, week_starts_on:, fixed_weeks:, show_week_number:, disabled:, hidden:, modifiers:, modifiers_class_names:,
                 class_names:, formatters:, components:, start_month:, end_month:, min:, max:, required:, exclude_disabled:,
                 reset_on_select:, disable_navigation:, hide_navigation:, hide_weekdays:, paged_navigation:, auto_focus:, footer:, dir:,
                 name:, input:, label:, close_on_select:)
    @mode = enum(mode, MODES, "mode", allow_nil: true)
    @caption_layout = enum(caption_layout, CAPTION_LAYOUTS, "caption_layout")
    @button_variant = enum(button_variant, Chadcn::Button::VARIANTS.keys, "button_variant")
    @dir = enum(dir, DIRS, "dir", allow_nil: true)
    raise ArgumentError, "components: render overrides are not portable; only nil or {} are accepted" unless components.nil? || components == {}

    @locale = Chadcn::Calendar::Locale.new(locale)
    @number_of_months = positive_integer(number_of_months, "number_of_months")
    @week_starts_on = week_start(week_starts_on)
    @today = Chadcn::Calendar::Dates.iso(today, "today")
    @month = Chadcn::Calendar::Dates.first_of_month(month, "month")
    @default_month = Chadcn::Calendar::Dates.first_of_month(default_month, "default_month")
    @start_month = Chadcn::Calendar::Dates.first_of_month(start_month, "start_month")
    @end_month = Chadcn::Calendar::Dates.first_of_month(end_month, "end_month")
    raise ArgumentError, "selected: needs a mode (#{MODES.join(', ')})" if !selected.nil? && @mode.nil?
    raise ArgumentError, "name: needs a mode (#{MODES.join(', ')})" if name && @mode.nil?

    @selected = selection(selected)
    @class_names = class_name_overrides(class_names)
    @modifiers_class_names = (modifiers_class_names || {}).to_h { |key, value| [ key.to_s, value.to_s ] }
    @modifiers = (modifiers || {}).to_h { |key, value| [ key.to_s, Chadcn::Calendar::Dates.matcher(value, "modifiers[#{key}]") ] }
    @show_week_number = show_week_number
    @hide_navigation = hide_navigation
    @hide_weekdays = hide_weekdays
    @footer = footer
    @name = name&.to_s
    @required = required
    @flags = { "showOutsideDays" => show_outside_days, "fixedWeeks" => fixed_weeks, "excludeDisabled" => exclude_disabled,
               "resetOnSelect" => reset_on_select, "disableNavigation" => disable_navigation, "pagedNavigation" => paged_navigation,
               "autoFocus" => auto_focus, "closeOnSelect" => close_on_select }
    @disabled = disabled.nil? ? nil : Chadcn::Calendar::Dates.matcher(disabled, "disabled")
    @hidden = hidden.nil? ? nil : Chadcn::Calendar::Dates.matcher(hidden, "hidden")
    @min = integer_or_nil(min, "min")
    @max = integer_or_nil(max, "max")
    @formatters = formatter_options(formatters)
    @input = input_selectors(input)
    @label = label&.to_s
  end

  # @return [Boolean] whether a year dropdown is shown (it brings the default navigation bounds)
  def year_dropdown? = %w[dropdown dropdown-years].include?(@caption_layout)

  # @return [Boolean] whether navigation is turned off
  def disable_navigation? = @flags["disableNavigation"]

  # @return [Boolean] whether the root has `data-multiple-months`
  def multiple_months? = @number_of_months > 1

  # The hash the controller reads from `data-chadcn--calendar-config-value` (camelCase keys, dates as ISO strings). Nil entries are dropped.
  #
  # @param classes [Hash{Symbol => String}] the finished class strings ({Chadcn::Calendar::Classes.build})
  # @return [Hash{String => Object}]
  def config(classes)
    {
      "mode" => @mode, "selected" => @selected, "defaultMonth" => @default_month, "today" => @today,
      "numberOfMonths" => @number_of_months, "captionLayout" => @caption_layout, "showWeekNumber" => @show_week_number,
      "hideWeekdays" => @hide_weekdays, "locale" => @locale.intl_tag, "localeKind" => @locale.kind,
      "yearFirst" => @locale.year_first?, "weekStartsOn" => @week_starts_on || @locale.week_starts_on,
      "firstWeekContainsDate" => @locale.first_week_contains_date, "disabled" => @disabled, "hidden" => @hidden, "modifiers" => @modifiers,
      "modifiersClassNames" => @modifiers_class_names, "dayClasses" => day_classes(classes),
      "startMonth" => @start_month, "endMonth" => @end_month, "min" => @min, "max" => @max, "required" => @required, "dir" => @dir,
      "formatters" => @formatters, "labels" => @locale.labels, "input" => @input, "label" => @label
    }.merge(@flags).compact
  end

  # @param classes [Hash{Symbol => String}] the finished class strings
  # @return [Hash{Symbol => String}] the day-cell entries
  def day_classes(classes)
    classes.select { |key, _| key == :day || Chadcn::Calendar::Classes::DAY_FLAGS.include?(key) }
  end

  # Whether the previous / next nav button starts disabled, as far as the server can tell (today is the server date when `today:` is
  # nil; the controller re-syncs the buttons on connect).
  #
  # @return [Hash{Symbol => Boolean}] `{ previous:, next: }`, true when the button is enabled
  def navigation
    first = first_month
    start = nav_start
    finish = nav_end
    {
      previous: !disable_navigation? && (start.nil? || month_difference(first, start).positive?),
      next: !disable_navigation? && (finish.nil? || month_difference(finish, first) >= @number_of_months)
    }
  end

  private

  def enum(value, allowed, name, allow_nil: false)
    return nil if value.nil? && allow_nil

    normalized = value.is_a?(Symbol) ? value.name.tr("_", "-") : value.to_s
    return normalized if allowed.include?(normalized)

    raise ArgumentError, "unknown #{name}: #{value.inspect} (expected one of #{allowed.join(', ')})"
  end

  def positive_integer(value, name)
    return value if value.is_a?(Integer) && value.positive?

    raise ArgumentError, "#{name} must be a positive Integer, got #{value.inspect}"
  end

  def integer_or_nil(value, name)
    return if value.nil?
    return value if value.is_a?(Integer) && value >= 0

    raise ArgumentError, "#{name} must be a non-negative Integer, got #{value.inspect}"
  end

  def week_start(value)
    return if value.nil?

    day = value.is_a?(String) && value.match?(/\A\d\z/) ? value.to_i : value
    return day if day.is_a?(Integer) && day.between?(0, 6)

    raise ArgumentError, "week_starts_on must be an Integer 0..6 (0 = Sunday), got #{value.inspect}"
  end

  def selection(value)
    return if value.nil? || @mode.nil?

    case @mode
    when "single" then Chadcn::Calendar::Dates.iso(value, "selected")
    when "multiple"
      raise ArgumentError, "selected must be an Array of dates for mode multiple, got #{value.inspect}" unless value.is_a?(Array)

      value.map { |date| Chadcn::Calendar::Dates.iso(date, "selected") }
    else Chadcn::Calendar::Dates.range(value)
    end
  end

  def class_name_overrides(value)
    (value || {}).to_h do |key, classes|
      symbol = key.to_s.tr("-", "_").to_sym
      raise ArgumentError, "unknown class_names key #{key.inspect} (expected one of #{Chadcn::Calendar::Classes::KEYS.join(', ')})" unless Chadcn::Calendar::Classes::KEYS.include?(symbol)

      [ symbol, classes ]
    end
  end

  def formatter_options(value)
    (value || {}).to_h do |key, options|
      name = key.to_s
      raise ArgumentError, "unknown formatter #{key.inspect} (expected one of #{FORMATTERS.join(', ')})" unless FORMATTERS.include?(name)
      raise ArgumentError, "formatters[#{key}] must be a Hash of Intl.DateTimeFormat options (functions are not portable)" unless options.is_a?(Hash)

      [ camelize(name), options.to_h { |option, setting| [ camelize(option.to_s), setting.is_a?(Symbol) ? setting.name : setting ] } ]
    end
  end

  def camelize(name) = name.gsub(/_([a-z])/) { Regexp.last_match(1).upcase }

  def input_selectors(value)
    case value
    when nil, String then value
    when Hash
      pairs = value.transform_keys(&:to_s)
      raise ArgumentError, "input: { from:, to: } is only valid for mode range" unless @mode == "range"
      raise ArgumentError, "input: { from:, to: } needs exactly a from and a to selector String" unless pairs.keys.sort == %w[from to] && pairs.values.all?(String)

      pairs
    else raise ArgumentError, "input: takes a selector String or { from:, to: } selectors, got #{value.inspect}"
    end
  end

  def month_difference(left, right) = ((left.year - right.year) * 12) + left.month - right.month

  def today_date = @today ? Date.iso8601(@today) : Date.today

  def nav_start
    return Date.iso8601(@start_month) if @start_month

    Date.new(today_date.year - 100, 1, 1) if year_dropdown?
  end

  def nav_end
    if @end_month
      Date.iso8601(@end_month).next_month.prev_day
    elsif year_dropdown?
      Date.new(today_date.year, 12, 31)
    end
  end

  # react-day-picker getInitialMonth.
  def first_month
    first = Date.iso8601(@month || @default_month || today_date.iso8601)
    finish = nav_end
    start = nav_start
    first = finish << (@number_of_months - 1) if finish && month_difference(finish, first) < @number_of_months - 1
    first = start if start && month_difference(first, start).negative?
    Date.new(first.year, first.month, 1)
  end
end

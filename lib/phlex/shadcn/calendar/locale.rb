# frozen_string_literal: true

# Locale resolution of Calendar (spec calendar.md, "Text and labels"): react-day-picker formats with date-fns patterns and ships
# translated labels per locale. Only nil/`en`/`en-US` and `es` are reproduced exactly; every other tag falls back to `Intl` with
# the English labels.
#
# @api private
class Phlex::Shadcn::Calendar::Locale
  # Translated labels of the exact locales (rdp locale/en-US.js and locale/es.js).
  LABELS = {
    "en" => {
      "nav" => "Navigation bar", "previous" => "Go to the Previous Month", "next" => "Go to the Next Month",
      "monthDropdown" => "Choose the Month", "yearDropdown" => "Choose the Year", "weekNumberHeader" => "Week Number",
      "weekNumber" => "Week", "today" => "Today", "selected" => "selected"
    }.freeze,
    "es" => {
      "nav" => "Barra de navegación", "previous" => "Ir al mes anterior", "next" => "Ir al mes siguiente",
      "monthDropdown" => "Elegir el mes", "yearDropdown" => "Elegir el año", "weekNumberHeader" => "Número de semana",
      "weekNumber" => "Semana", "today" => "Hoy", "selected" => "seleccionado"
    }.freeze
  }.freeze

  # Week settings of date-fns for the exact locales: `[weekStartsOn, firstWeekContainsDate]`.
  WEEK_SETTINGS = { "en" => [ 0, 1 ].freeze, "es" => [ 1, 1 ].freeze }.freeze

  # Locales that put the year before the month (date-fns/react-day-picker `DateLib.yearFirstLocales`).
  YEAR_FIRST = %w[eu hu ja ja-Hira ja-JP ko ko-KR lt lt-LT lv lv-LV mn mn-MN zh zh-CN zh-HK zh-TW].freeze

  # Shape of a BCP 47 language tag, as far as Calendar needs to trust it.
  TAG = /\A[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*\z/

  # @return [String, nil] the tag as given (nil = react-day-picker's default, en-US)
  attr_reader :tag

  # @param tag [String, Symbol, nil] a BCP 47 tag such as `"es"` or `"en-GB"`
  # @raise [ArgumentError] for a value that is not a language tag
  def initialize(tag)
    @tag = tag&.to_s
    raise ArgumentError, "locale must be a BCP 47 tag such as \"es\" or \"en-GB\", got #{tag.inspect}" if @tag && !TAG.match?(@tag)
  end

  # @return [String] `"en"` (nil, `en`, `en-US`), `"es"` (`es`, `es-*`) or `"other"`
  def kind
    @kind ||= resolve_kind
  end

  # @return [String] the tag `Intl` formats with (`en-US` when none or `en`)
  def intl_tag = kind == "en" ? "en-US" : @tag

  # @return [String] the default `lang` of the root: rdp's locale code
  def lang = intl_tag

  # @return [Hash{String => String}] the translated labels (English for "other")
  def labels = LABELS.fetch(kind == "es" ? "es" : "en")

  # @return [Integer, nil] date-fns `weekStartsOn`; nil for "other" (the controller asks `Intl.Locale`)
  def week_starts_on = WEEK_SETTINGS[kind]&.first

  # @return [Integer, nil] date-fns `firstWeekContainsDate`; nil for "other" (the controller uses `weekInfo.minimalDays` or 1)
  def first_week_contains_date = WEEK_SETTINGS[kind]&.last

  # @return [Boolean] whether the month is written after the year
  def year_first? = YEAR_FIRST.include?(@tag)

  private

  def resolve_kind
    case @tag
    when nil, "en", "en-US" then "en"
    when "es", /\Aes-/ then "es"
    else "other"
    end
  end
end

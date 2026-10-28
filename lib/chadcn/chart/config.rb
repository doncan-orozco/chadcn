# frozen_string_literal: true

# The `ChartConfig` type of shadcn's `chart.tsx`: for each series key a `label`, an `icon` and either one `color` or a `theme`
# (`light`/`dark` colors), never both. Normalizes a Hash of that shape (string or symbol keys) and answers the lookups
# `getPayloadConfigFromPayload` does for the tooltip and legend contents.
#
# The keys and colors end up in a `<style>` element (see {Chadcn::Chart::Style}), so they are validated here: a key is
# letters, digits, `_` and `-`; a color has none of `<`, `>`, `{`, `}`, `;`, backslash or `/*`. React accepts anything and writes
# it raw; this is the one place the port raises where React does not (dev/port/deviations/chart.json).
#
# @example
#   Chadcn::Chart::Config.new(
#     desktop: { label: "Desktop", color: "var(--chart-1)" },
#     mobile: { label: "Mobile", theme: { light: "#2563eb", dark: "#60a5fa" } }
#   )
class Chadcn::Chart::Config
  # One series. `icon` is a Lucide icon name (String/Symbol) or a Phlex component instance; `label` is text or a component instance.
  Entry = Data.define(:label, :icon, :color, :theme)

  # The themes of `chart.tsx` (`THEMES`) and the selector prefix of each.
  THEMES = { "light" => "", "dark" => ".dark" }.freeze

  KEY = /\A[A-Za-z0-9_-]+\z/
  private_constant :KEY
  COLOR = %r{\A(?![\s\S]*/\*)[^<>{};\\]+\z}
  private_constant :COLOR
  ENTRY_KEYS = %w[label icon color theme].freeze
  private_constant :ENTRY_KEYS

  # @param entries [Hash, Chadcn::Chart::Config, nil] the config as a Hash, positional or as keywords
  # @raise [ArgumentError] on a key or color that cannot go into the style, an unknown entry option, or `color` together with `theme`
  def initialize(entries = nil, **keywords)
    source = entries.is_a?(self.class) ? entries.to_h : (entries || {}).to_h
    @entries = source.merge(keywords) { |_key, _old, new| new }
                     .to_h { |key, options| [ validated_key(key), build_entry(key, options) ] }
                     .freeze
  end

  # @param key [String, Symbol]
  # @return [Entry, nil]
  def [](key) = @entries[key.to_s]

  # @param key [String, Symbol]
  def key?(key) = @entries.key?(key.to_s)

  # @return [Array<String>] the keys, in the order given
  def keys = @entries.keys

  # @yieldparam key [String]
  # @yieldparam entry [Entry]
  def each(&) = @entries.each(&)

  # @return [Boolean]
  def empty? = @entries.empty?

  # @return [Hash{String => Entry}] the entries with a color or a theme (what {Chadcn::Chart::Style} writes)
  def color_entries = @entries.select { |_key, entry| entry.theme || entry.color }

  # @return [Hash{String => Hash}] the normalized entries as plain Hashes
  def to_h = @entries.transform_values { |entry| entry.to_h.compact }

  # The config entry of a tooltip/legend payload item, with the lookup order of `getPayloadConfigFromPayload` (`chart.tsx`):
  # when the payload item has a String under `key` that String names the entry, else the String under `key` in the item's own
  # `payload` (the data row) does, else `key` itself.
  #
  # @param payload [Hash, nil] the tooltip/legend item (`name`, `data_key`, `value`, `color`, `payload` ...); anything else answers nil
  # @param key [String, Symbol]
  # @return [Entry, nil]
  def payload_config(payload, key)
    return unless payload.is_a?(Hash)

    key = key.to_s
    row = fetch_value(payload, :payload)
    row = nil unless row.is_a?(Hash)
    named = fetch_value(payload, key)
    named = fetch_value(row, key) if !named.is_a?(String) && row
    @entries[named.is_a?(String) && @entries.key?(named) ? named : key]
  end

  private

  def validated_key(key)
    name = key.to_s
    return name if KEY.match?(name)

    raise ArgumentError, "chart config key #{key.inspect} must be letters, digits, _ and - (it becomes the CSS variable --color-<key>)"
  end

  def build_entry(key, options)
    unless options.is_a?(Hash)
      raise ArgumentError, "chart config #{key.inspect} must be a Hash (label:, icon:, color: or theme:), got #{options.inspect}"
    end

    options = options.transform_keys(&:to_s)
    unknown = options.keys - ENTRY_KEYS
    raise ArgumentError, "chart config #{key.inspect}: unknown option #{unknown.first.inspect} (use #{ENTRY_KEYS.join(', ')})" if unknown.any?

    color = options["color"]
    theme = options["theme"]
    raise ArgumentError, "chart config #{key.inspect}: color: and theme: are mutually exclusive" if !color.nil? && !theme.nil?

    Entry.new(label: options["label"], icon: options["icon"], color: validated_color(key, color), theme: validated_theme(key, theme))
  end

  def validated_theme(key, theme)
    return if theme.nil?
    raise ArgumentError, "chart config #{key.inspect}: theme: must be a Hash with light: and dark:, got #{theme.inspect}" unless theme.is_a?(Hash)

    theme = theme.transform_keys(&:to_s)
    unknown = theme.keys - THEMES.keys
    raise ArgumentError, "chart config #{key.inspect}: unknown theme #{unknown.first.inspect} (use #{THEMES.keys.join(', ')})" if unknown.any?

    theme.to_h { |name, color| [ name, validated_color(key, color) ] }.compact.freeze
  end

  def validated_color(key, color)
    return if color.nil?

    color = color.to_s
    return color if COLOR.match?(color)

    raise ArgumentError, "chart config #{key.inspect}: color #{color.inspect} cannot go into a style (no < > { } ; \\ or /*)"
  end

  # A Hash value by string or symbol key (the payload items come from Ruby code or from JSON).
  def fetch_value(hash, key)
    return unless hash

    hash.fetch(key.to_sym) { hash[key.to_s] }
  end
end

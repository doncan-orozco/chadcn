# frozen_string_literal: true

require "json"

# What the Combobox parts share while one root renders: the options, the item model (labels, form values, equality) and the
# initial state. Items are Strings, Hashes (`value:`/`label:`, String or Symbol keys alike) or groups (`{ value:, items: [...] }`).
#
# @api private
class Phlex::Shadcn::Combobox::Model
  FILTERS = %w[fuzzy contains].freeze
  private_constant :FILTERS

  attr_reader :id, :items, :name, :form, :auto_complete, :limit, :locale, :filter, :auto_highlight, :selection, :input_value,
              :sequence, :list_id, :popup_id

  # Per-render counters and flags the parts write while they render (ids of items, where the input lives).
  attr_accessor :item_index, :input_outside, :in_popup

  # @param options [Hash] the full options hash of {Phlex::Shadcn::Combobox#initialize}
  # @param sequence [Integer] render-wide counter (ids of roots without `id:`)
  def initialize(options, sequence)
    opts = @opts = options
    @id = (opts[:id] || "combobox-#{sequence}").to_s
    @sequence = sequence
    @items = opts[:items]
    @name = opts[:name]
    @form = opts[:form]
    @auto_complete = opts[:auto_complete]
    @limit = Integer(opts[:limit])
    @locale = opts[:locale]
    @filter = normalize_filter(opts[:filter])
    @auto_highlight = normalize_auto_highlight(opts[:auto_highlight])
    @label_proc = opts[:item_to_string_label]
    @value_proc = opts[:item_to_string_value]
    @equal_proc = opts[:item_equal_to_value]
    @item_index = 0
    @counter = 0
    @selection = resolve_selection
    @input_value = resolve_input_value
    @list_id = "#{@id}-list"
    @popup_id = "#{@id}-popup"
  end

  %i[multiple disabled read_only required keep_highlight highlight_item_on_hover loop_focus open_on_input_click modal
     submit_on_item_click].each do |option|
    define_method(:"#{option}?") { !!@opts[option] }
  end

  # @return [Boolean] whether `items:` was given (otherwise the items are static children and nothing is filtered)
  def items? = !@items.nil?

  # @return [Boolean] whether `value:` controls the selection
  def value_controlled? = !@opts[:value].nil?

  # @return [Boolean] whether `open:` controls the popup
  def open_controlled? = !@opts[:open].nil?

  # @return [Boolean] whether `input_value:` controls the text of the input
  def input_value_controlled? = !@opts[:input_value].nil?

  # @return [Boolean] whether the input text was given (`input_value:`/`default_input_value:`)
  def input_value_given? = !@opts[:input_value].nil? || !@opts[:default_input_value].nil?

  # @return [Boolean] initial popup state
  def open? = @opts[:open].nil? ? !!@opts[:default_open] : !!@opts[:open]

  # @return [Boolean] whether the items are groups
  def grouped? = items? && group?(@items.first)

  # @return [Array] the leaf items (groups flattened)
  def flat_items
    return [] unless items?

    grouped? ? @items.flat_map { |group| read(group, :items) || [] } : @items
  end

  # @return [Boolean] whether `item` is a group (a Hash carrying an `items` Array)
  def group?(item) = item.is_a?(Hash) && read(item, :items).is_a?(Array)

  # Reads a Hash entry by Symbol or String key.
  def read(hash, key) = hash.key?(key) ? hash[key] : hash[key.to_s]

  # @return [Boolean] whether the Hash has the entry under a Symbol or String key
  def key?(hash, key) = hash.key?(key) || hash.key?(key.to_s)

  # Base UI `stringifyAsLabel`.
  def label(item)
    return @label_proc.call(item).to_s if @label_proc && !item.nil?

    if item.is_a?(Hash)
      label = read(item, :label)
      return label.to_s unless label.nil?
      return read(item, :value).to_s if key?(item, :value)
    end
    serialize(item)
  end

  # Base UI `stringifyAsValue`: what the item submits in a form (and its identity on the client).
  def form_value(item)
    return @value_proc.call(item).to_s if @value_proc && !item.nil?
    return serialize(read(item, :value)) if item.is_a?(Hash) && key?(item, :value) && key?(item, :label)

    serialize(item)
  end

  # Base UI `serializeValue`.
  def serialize(value)
    case value
    when nil then ""
    when String then value
    when Symbol, Numeric, true, false then value.to_s
    else JSON.generate(value)
    end
  end

  # @return [Boolean] whether the two items are the same (`item_equal_to_value:`, else `==` ignoring Hash key types)
  def same?(item, other)
    return !!@equal_proc.call(item, other) if @equal_proc

    plain(item) == plain(other)
  end

  # @return [Boolean] whether `item` is part of the initial selection
  def selected?(item) = @selection.any? { |chosen| same?(chosen, item) }

  # @return [Array<String>] form values of the initial selection
  def selected_keys = @selection.map { |item| form_value(item) }

  # Next unique suffix for ids generated while rendering.
  def next_counter = @counter += 1

  # @return [Array<Hash>] `{ k:, l: }` (form value, label) of every list item, for the client to filter and label
  def registry = entries(flat_items)

  # @return [Array<Hash>] `{ k:, l: }` of the selected items that are not list items (the client only needs their labels)
  def extras = entries(@selection.reject { |chosen| flat_items.any? { |item| same?(item, chosen) } })

  private

  def entries(list) = list.map { |item| { k: form_value(item), l: label(item) } }

  # The selected items, as the list items they equal (so labels and form values come out right), in selection order. A scalar also
  # matches the Hash item whose `value` it is (Base UI `resolveSelectedLabel`).
  def resolve_selection
    chosen = @opts[:value].nil? ? @opts[:default_value] : @opts[:value]
    list = multiple? && chosen.is_a?(Array) ? chosen : [ chosen ].compact
    list.map { |item| flat_items.find { |candidate| same?(candidate, item) || value_of?(candidate, item) } || item }
  end

  def value_of?(candidate, item) = candidate.is_a?(Hash) && !item.is_a?(Hash) && key?(candidate, :value) && read(candidate, :value) == item

  def resolve_input_value
    given = @opts[:input_value].nil? ? @opts[:default_input_value] : @opts[:input_value]
    return given.to_s unless given.nil?

    !multiple? && @selection.any? ? label(@selection.first) : ""
  end

  def normalize_filter(filter)
    return if filter.nil?

    name = filter.to_s
    raise ArgumentError, "unknown filter: #{filter.inspect} (expected one of #{FILTERS.join(', ')} or nil)" unless FILTERS.include?(name)

    name
  end

  def normalize_auto_highlight(value)
    return "always" if value.to_s == "always"

    value ? true : false
  end

  # Hash keys as Strings, recursively, so `{ value: "a" }` equals `{ "value" => "a" }`.
  def plain(value)
    case value
    when Hash then value.to_h { |key, entry| [ key.to_s, plain(entry) ] }
    when Array then value.map { |entry| plain(entry) }
    else value
    end
  end
end

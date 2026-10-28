# frozen_string_literal: true

# shadcn `ChartTooltip` (recharts' `Tooltip`): the tooltip a chart root declares. It renders nothing where it is written; the
# chart reads {#options} and {#content_element} and writes the per-index tooltip templates (dev/port/specs/chart.md, "Tooltip").
#
# @example
#   Chadcn::Chart::Tooltip.new(default_index: 1, content: Chadcn::Chart::Tooltip::Content.new(hide_label: true))
class Chadcn::Chart::Tooltip < Chadcn::Base
  # Values of `trigger:`.
  TRIGGERS = %i[hover click].freeze
  TRISTATE = [ nil, true, false ].freeze
  private_constant :TRISTATE

  # @return [Chadcn::Chart::Tooltip::Content, nil] the declared content (recharts' `content` prop)
  attr_reader :content_element
  # @return [Hash{Symbol => Object}] the keywords with recharts' defaults applied, frozen
  attr_reader :options

  # @param content [Chadcn::Chart::Tooltip::Content, nil]
  # @param cursor [Boolean, Hash] the hover cursor; a Hash is its SVG attributes (`stroke:`, `stroke_dasharray:`, `fill:` ...)
  # @param default_index [Integer, String, nil] the index shown before any interaction
  # @param active [Boolean, nil] nil follows the interaction, true keeps it visible, false never shows it
  # @param shared [Boolean, nil] nil follows the chart's event type; false asks for item tooltips (bar and radial bar charts only)
  # @param trigger [Symbol] `:hover` or `:click`
  # @param offset [Numeric, Hash] distance from the pointer; a Hash is `x:` and `y:`
  # @param allow_escape_view_box [Hash] `x:` and `y:`
  # @param reverse_direction [Hash] `x:` and `y:`
  # @param position [Hash, nil] a fixed position, `x:` and `y:` (either may be nil)
  # @param is_animation_active [Symbol, Boolean] `:auto`, true or false
  # @param animation_duration [Numeric] ms
  # @param animation_easing [Symbol, String]
  # @param wrapper_style [Hash, String, nil] style of the `recharts-tooltip-wrapper` div
  # @param filter_null [Boolean] drop payload entries whose value is nil
  # @param include_hidden [Boolean] keep payload entries of hidden series
  # @param axis_id [Integer] the axis the tooltip follows
  # @param payload_uniq_by [Boolean] unique payload by `data_key`
  # @param formatter [#call, nil] overrides the `formatter:` of the content (recharts clones the content with the Tooltip's props)
  # @param label_formatter [#call, nil] overrides the `label_formatter:` of the content
  # @param separator [String] accepted for parity with recharts, ignored by the shadcn content
  # @param content_style [Hash, nil] accepted and ignored (only recharts' default content reads it)
  # @param item_sorter [Symbol, nil] accepted and ignored by the shadcn content
  # @param attrs [Hash] attributes of the `recharts-tooltip-wrapper` div (a chadcn addition); `class:` is merged
  # @raise [ArgumentError] on a `trigger:` that is neither `:hover` nor `:click`, or a `content:` that is not a tooltip content
  def initialize(content: nil, cursor: true, default_index: nil, active: nil, shared: nil, trigger: :hover, offset: 10,
                 allow_escape_view_box: { x: false, y: false }, reverse_direction: { x: false, y: false }, position: nil,
                 is_animation_active: :auto, animation_duration: 400, animation_easing: :ease, wrapper_style: nil, filter_null: true,
                 include_hidden: false, axis_id: 0, payload_uniq_by: false, formatter: nil, label_formatter: nil,
                 separator: " : ", content_style: nil, item_sorter: :name,
                 **attrs)
    unless trigger.respond_to?(:to_sym) && TRIGGERS.include?(trigger.to_sym)
      raise ArgumentError, "trigger: must be one of #{TRIGGERS.map(&:inspect).join(', ')} (got #{trigger.inspect})"
    end
    unless content.nil? || content.is_a?(Chadcn::Chart::Tooltip::Content)
      raise ArgumentError, "content: must be a Chadcn::Chart::Tooltip::Content (got #{content.class})"
    end
    raise ArgumentError, "active: must be true, false or nil (got #{active.inspect})" unless TRISTATE.include?(active)
    raise ArgumentError, "shared: must be true, false or nil (got #{shared.inspect})" unless TRISTATE.include?(shared)

    @content_element = content
    @options = {
      cursor: cursor, default_index: default_index, active: active, shared: shared, trigger: trigger.to_sym, offset: offset,
      allow_escape_view_box: allow_escape_view_box, reverse_direction: reverse_direction, position: position,
      is_animation_active: is_animation_active, animation_duration: animation_duration, animation_easing: animation_easing,
      wrapper_style: wrapper_style, filter_null: filter_null, include_hidden: include_hidden, axis_id: axis_id,
      payload_uniq_by: payload_uniq_by, formatter: formatter, label_formatter: label_formatter,
      separator: separator, content_style: content_style, item_sorter: item_sorter, attrs: attrs
    }.freeze
    super()
  end

  # A declaration renders nothing where it is written; the chart that contains it draws the tooltip.
  #
  # @return [void]
  def view_template; end

  # Nested in this file, not in `tooltip/content.rb`: `Base.const_added` loads the parts of `Chart` while Zeitwerk is still
  # registering them, before it can hook the namespace of a file that also has a directory, so a `tooltip/` directory
  # would stay unregistered (epic chart, item #45).

  # shadcn `ChartTooltipContent`: the tooltip box of a chart, rendered from a payload (the series at the hovered category) and the
  # config of the enclosing {Chadcn::Chart::Container}. Renders nothing for an empty payload.
  #
  # Declare it on a {Chadcn::Chart::Tooltip} (`content:`); the chart renders it once per tooltip index with that index's payload and
  # label. Rendered by hand it needs a `payload:` and has to be inside a container, like React's `useChart()`.
  #
  # A payload item is a Hash: `name:`, `data_key:`, `value:`, `color:`, `type:` (`:none` drops it), `payload:` (the data row, whose
  # `fill:` colors the indicator). `**attrs` land on the root div (a chadcn addition: React's component does not spread props).
  #
  # @example
  #   render Chadcn::Chart::Tooltip::Content.new(
  #     indicator: :line, label: "January",
  #     payload: [ { name: "desktop", data_key: "desktop", value: 1860, color: "var(--color-desktop)" } ]
  #   )
  class Content < Chadcn::Base
    include Chadcn::Chart::ContentSupport

    INDICATORS = %w[dot line dashed].freeze
    private_constant :INDICATORS

    ROOT_CLASSES = "grid min-w-[8rem] items-start gap-1.5 rounded-lg border border-border/50 bg-background px-2.5 py-1.5 text-xs shadow-xl"
    private_constant :ROOT_CLASSES

    ITEM_CLASSES = "flex w-full flex-wrap items-stretch gap-2 [&>svg]:h-2.5 [&>svg]:w-2.5 [&>svg]:text-muted-foreground"
    private_constant :ITEM_CLASSES

    # @param indicator [Symbol, String] `:dot`, `:line` or `:dashed`
    # @param hide_label [Boolean]
    # @param hide_indicator [Boolean]
    # @param label [String, nil] the category label; a config key is replaced by its label
    # @param label_formatter [#call, nil] `(label, payload)`, returns a String or a component; its result replaces the label
    # @param label_class_name [String, nil] classes of the label div (React `labelClassName`)
    # @param formatter [#call, nil] `(value, name, item, index, row)` renders an item instead of the default markup
    # @param color [String, nil] color of every indicator
    # @param name_key [String, Symbol, nil] the payload key whose value names the config entry of an item
    # @param label_key [String, Symbol, nil] same for the label
    # @param payload [Array<Hash>, nil] the series at the hovered category
    # @param attrs [Hash] attributes of the root div; `class:` is merged last
    # @raise [ArgumentError] on an unknown `indicator:` or a `payload:` that is not an Array of Hashes
    def initialize(indicator: :dot, hide_label: false, hide_indicator: false, label: nil, label_formatter: nil, label_class_name: nil,
                   formatter: nil, color: nil, name_key: nil, label_key: nil, payload: [], **attrs)
      raise ArgumentError, "indicator: must be one of #{INDICATORS.join(', ')} (got #{indicator.inspect})" unless INDICATORS.include?(indicator.to_s)

      @options = { indicator: indicator.to_s, hide_label: hide_label, hide_indicator: hide_indicator, label: label,
                   label_formatter: label_formatter, label_class_name: label_class_name, formatter: formatter, color: color,
                   name_key: name_key, label_key: label_key, attrs: attrs }.freeze
      @payload = validated_payload(payload)
      super()
    end

    # @return [void]
    def view_template
      return if @payload.empty?

      config = chart_config
      nest_label = @payload.length == 1 && option(:indicator) != "dot"
      label = tooltip_label(config)
      div(**merge_attrs({ class: ROOT_CLASSES }, option(:attrs))) do
        render_label(label) unless nest_label
        div(class: "grid gap-1.5") do
          # `payload.filter(type !== "none").map((item, index) => ...)`: the formatter's index counts the visible items only.
          @payload.reject { |item| item_value(item, :type).to_s == "none" }.each_with_index do |item, index|
            render_item(config, item, index, nest_label, label)
          end
        end
      end
    end

    private

    # The label as a one-element array (the text or component after the formatter), or nil when there is none. `chart.tsx` `tooltipLabel`.
    def tooltip_label(config)
      return if option(:hide_label) || @payload.empty?

      item = @payload.first
      value = if !option(:label_key) && option(:label).is_a?(String)
        config_label = config[option(:label)]&.label
        config_label.nil? ? option(:label) : config_label
      else
        config.payload_config(item, config_key(option(:label_key), item, :data_key, :name))&.label
      end
      return [ option(:label_formatter).call(value, @payload) ] if option(:label_formatter)

      [ value ] unless value.nil? || value == false || value == ""
    end

    def render_label(label)
      return unless label

      div(class: cn("font-medium", option(:label_class_name))) { render_node(label.first) }
    end

    # The payload key that names a config entry: the explicit key, else the first item key that has a value, else "value".
    def config_key(explicit, item, *item_keys)
      return explicit.to_s if explicit

      item_keys.each do |item_key|
        found = item_value(item, item_key)
        return found.to_s if found
      end
      "value"
    end

    def render_item(config, item, index, nest_label, label)
      value = item_value(item, :value)
      name = item_value(item, :name)
      row = item_value(item, :payload)

      div(class: cn(ITEM_CLASSES, option(:indicator) == "dot" ? "items-center" : nil)) do
        if option(:formatter) && item_key?(item, :value) && js_truthy?(name)
          render_node(option(:formatter).call(value, name, item, index, row))
        else
          item_config = config.payload_config(item, config_key(option(:name_key), item, :name, :data_key))
          render_default_item(item_config, item, indicator_color(item, row), nest_label, label)
        end
      end
    end

    # The color of an indicator: the content's `color:`, then the fill of the data row, then the color of the item (`chart.tsx`).
    def indicator_color(item, row)
      row_fill = row.is_a?(Hash) ? item_value(row, :fill) : nil
      option(:color) || row_fill || item_value(item, :color)
    end

    def render_default_item(item_config, item, color, nest_label, label)
      if item_config&.icon
        render_icon(item_config.icon)
      elsif !option(:hide_indicator)
        div(class: indicator_classes(nest_label), style: ("--color-bg: #{color}; --color-border: #{color};" if color))
      end
      div(class: cn("flex flex-1 justify-between leading-none", nest_label ? "items-end" : "items-center")) do
        div(class: "grid gap-1.5") do
          render_label(label) if nest_label
          span(class: "text-muted-foreground") { render_node(series_label(item_config, item)) }
        end
        value = item_value(item, :value)
        span(class: "font-mono font-medium text-foreground tabular-nums") { plain(locale_string(value)) } unless value.nil?
      end
    end

    # `itemConfig?.label ?? item.name`: only a missing label falls back to the series name.
    def series_label(item_config, item)
      label = item_config&.label
      label.nil? ? item_value(item, :name) : label
    end

    def indicator_classes(nest_label)
      cn("shrink-0 rounded-[2px] border-(--color-border) bg-(--color-bg)",
         { "h-2.5 w-2.5" => option(:indicator) == "dot",
           "w-1" => option(:indicator) == "line",
           "w-0 border-[1.5px] border-dashed bg-transparent" => option(:indicator) == "dashed",
           "my-0.5" => nest_label && option(:indicator) == "dashed" })
    end

    # The decimal ICU sees: floats by their shortest representation (1.0005 stays 1.0005, not its binary neighbor).
    def exact(number) = number.is_a?(Float) ? Rational(number.to_s) : number.to_r

    # JS `toLocaleString()` of the default (en-US) locale for a number: comma grouping, at most 3 fraction digits, half away from
    # zero; other values are `String(value)`.
    def locale_string(value)
      return value.to_s unless value.is_a?(Numeric) && value.real? && value.finite?

      whole, fraction = (exact(value).abs * 1000).round(half: :up).divmod(1000)
      "#{'-' if negative_sign?(value)}#{group_thousands(whole)}#{fraction_suffix(fraction)}"
    end

    # JS prints a negative zero (and a negative that rounds to zero) with its sign.
    def negative_sign?(value) = value.negative? || (value.is_a?(Float) && value.zero? && (1.0 / value).negative?)

    def group_thousands(whole) = whole.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, ",")

    def fraction_suffix(fraction)
      return "" if fraction.zero?

      ".#{format('%03d', fraction).sub(/0+\z/, '')}"
    end
  end
end

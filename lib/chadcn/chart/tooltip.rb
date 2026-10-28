# frozen_string_literal: true

# shadcn `ChartTooltip` (recharts' `Tooltip`): the tooltip a chart root declares. It renders nothing where it is written; the
# chart reads {#options} and {#content_element} and writes the per-index tooltip templates (dev/port/specs/chart.md, "Tooltip").
#
# @example
#   Chadcn::Chart::Tooltip.new(default_index: 1, content: Chadcn::Chart::Tooltip::Content.new(hide_label: true))
class Chadcn::Chart::Tooltip < Chadcn::Base
  # Values of `trigger:`.
  TRIGGERS = %i[hover click].freeze
  EVENT_TYPES = [ nil, true, false ].freeze
  private_constant :EVENT_TYPES

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
    unless TRIGGERS.include?(trigger&.to_sym)
      raise ArgumentError, "trigger: must be one of #{TRIGGERS.map(&:inspect).join(', ')} (got #{trigger.inspect})"
    end
    unless content.nil? || content.is_a?(Chadcn::Chart::Tooltip::Content)
      raise ArgumentError, "content: must be a Chadcn::Chart::Tooltip::Content (got #{content.class})"
    end
    raise ArgumentError, "active: must be true, false or nil (got #{active.inspect})" unless EVENT_TYPES.include?(active)
    raise ArgumentError, "shared: must be true, false or nil (got #{shared.inspect})" unless EVENT_TYPES.include?(shared)

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
    INDICATORS = %w[dot line dashed].freeze
    private_constant :INDICATORS

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
    # @param payload [Array<Hash>] the series at the hovered category
    # @param attrs [Hash] attributes of the root div; `class:` is merged last
    # @raise [ArgumentError] on an unknown `indicator:`
    def initialize(indicator: :dot, hide_label: false, hide_indicator: false, label: nil, label_formatter: nil, label_class_name: nil,
                   formatter: nil, color: nil, name_key: nil, label_key: nil, payload: [], **attrs)
      @indicator = indicator.to_s
      raise ArgumentError, "indicator: must be one of #{INDICATORS.join(', ')} (got #{indicator.inspect})" unless INDICATORS.include?(@indicator)

      @options = { indicator: indicator, hide_label: hide_label, hide_indicator: hide_indicator, label: label,
                   label_formatter: label_formatter, label_class_name: label_class_name, formatter: formatter, color: color, name_key: name_key,
                   label_key: label_key, **attrs }.freeze
      @hide_label = hide_label
      @hide_indicator = hide_indicator
      @label = label
      @label_formatter = label_formatter
      @label_class_name = label_class_name
      @formatter = formatter
      @color = color
      @name_key = name_key
      @label_key = label_key
      @payload = payload || []
      @attrs = attrs
      super()
    end

    # A copy with other options, e.g. the payload and label of one tooltip index.
    #
    # @api private
    # @return [Chadcn::Chart::Tooltip::Content]
    def with(**changes) = self.class.new(**@options, payload: @payload, **changes)

    # @return [void]
    def view_template
      return if @payload.empty?

      config = chart_config
      nest_label = @payload.length == 1 && @indicator != "dot"
      label = tooltip_label(config)
      div(**merge_attrs({ class: "grid min-w-[8rem] items-start gap-1.5 rounded-lg border border-border/50 bg-background px-2.5 py-1.5 text-xs shadow-xl" }, @attrs)) do
        render_label(label) unless nest_label
        div(class: "grid gap-1.5") do
          @payload.each_with_index do |item, index|
            next if item_value(item, :type).to_s == "none"

            render_item(config, item, index, nest_label ? label : nil)
          end
        end
      end
    end

    private

    def chart_config
      container = Chadcn::Chart::Container.current(context)
      raise ArgumentError, "#{self.class.name} has no Chart::Container around it; React's useChart() raises the same" unless container

      container.config
    end

    # The label as [kind, value]: nil (nothing), or the text/component after the formatter. `chart.tsx` `tooltipLabel`.
    def tooltip_label(config)
      return if @hide_label || @payload.empty?

      item = @payload.first
      key = (@label_key || item_value(item, :data_key) || item_value(item, :name) || "value").to_s
      item_config = config.payload_config(item, key)
      value = if !@label_key && @label.is_a?(String)
        config[@label]&.label || @label
      else
        item_config&.label
      end
      return [ @label_formatter.call(value, @payload) ] if @label_formatter

      [ value ] unless value.nil? || value == false || value == ""
    end

    def render_label(label)
      return unless label

      div(class: cn("font-medium", @label_class_name)) { render_node(label.first) }
    end

    def render_item(config, item, index, nested_label)
      key = (@name_key || item_value(item, :name) || item_value(item, :data_key) || "value").to_s
      item_config = config.payload_config(item, key)
      row = item_value(item, :payload)
      row_fill = row.is_a?(Hash) ? item_value(row, :fill) : nil
      indicator_color = @color || row_fill || item_value(item, :color)
      value = item_value(item, :value)
      name = item_value(item, :name)

      div(class: cn(ITEM_CLASSES, @indicator == "dot" && "items-center")) do
        if @formatter && !value.nil? && name
          render_node(@formatter.call(value, name, item, index, row))
        else
          render_default_item(item_config, item, indicator_color, nested_label)
        end
      end
    end

    def render_default_item(item_config, item, indicator_color, nested_label)
      nest_label = !nested_label.nil?
      if item_config&.icon
        render_icon(item_config.icon)
      elsif !@hide_indicator
        div(class: indicator_classes(nest_label), style: "--color-bg: #{indicator_color}; --color-border: #{indicator_color};")
      end
      div(class: cn("flex flex-1 justify-between leading-none", nest_label ? "items-end" : "items-center")) do
        div(class: "grid gap-1.5") do
          render_label(nested_label) if nest_label
          span(class: "text-muted-foreground") { render_node(item_config&.label || item_value(item, :name)) }
        end
        value = item_value(item, :value)
        span(class: "font-mono font-medium text-foreground tabular-nums") { plain(locale_string(value)) } unless value.nil?
      end
    end

    def indicator_classes(nest_label)
      cn("shrink-0 rounded-[2px] border-(--color-border) bg-(--color-bg)",
         { "h-2.5 w-2.5" => @indicator == "dot",
           "w-1" => @indicator == "line",
           "w-0 border-[1.5px] border-dashed bg-transparent" => @indicator == "dashed",
           "my-0.5" => nest_label && @indicator == "dashed" })
    end

    def render_icon(icon)
      render(icon.is_a?(Phlex::SGML) ? icon : Chadcn::Icon.new(icon))
    end

    def render_node(node)
      case node
      when nil, false then nil
      when Phlex::SGML then render(node)
      else plain(node.to_s)
      end
    end

    # A payload item by symbol or string key.
    def item_value(item, key)
      item.fetch(key) { item[key.to_s] }
    end

    # The decimal ICU sees: floats by their shortest representation (1.0005 stays 1.0005, not its binary neighbor).
    def exact(number) = number.is_a?(Float) ? Rational(number.to_s) : number.to_r

    # JS `toLocaleString()` of the default (en-US) locale for a number: comma grouping, at most 3 fraction digits, half away from
    # zero; other values are `String(value)`.
    def locale_string(value)
      return value.to_s unless value.is_a?(Numeric)
      return value.to_s unless value.is_a?(Integer) || (value.real? && (!value.respond_to?(:finite?) || value.finite?))

      scaled = (exact(value).abs * 1000).round(half: :up)
      whole, fraction = scaled.divmod(1000)
      digits = whole.to_s.reverse.scan(/\d{1,3}/).join(",").reverse
      fraction = format("%03d", fraction).sub(/0+\z/, "")
      "#{'-' if value.negative? || (value.is_a?(Float) && value.zero? && (1.0 / value).negative?)}#{digits}#{".#{fraction}" unless fraction.empty?}"
    end
  end
end

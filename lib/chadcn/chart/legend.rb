# frozen_string_literal: true

# shadcn `ChartLegend` (recharts' `Legend`): the legend a chart root declares. It renders nothing where it is written; the chart
# reads {#options} and {#content_element} and writes the legend wrapper with the content.
#
# @example
#   Chadcn::Chart::Legend.new(content: Chadcn::Chart::Legend::Content.new, vertical_align: :top)
class Chadcn::Chart::Legend < Chadcn::Base
  ALIGNMENTS = %i[top middle bottom].freeze

  # @return [Chadcn::Chart::Legend::Content, nil] the declared content (recharts' `content` prop)
  attr_reader :content_element
  # @return [Hash{Symbol => Object}] the keywords with recharts' defaults applied, frozen
  attr_reader :options

  # @param content [Chadcn::Chart::Legend::Content, nil]
  # @param vertical_align [Symbol] `:top`, `:middle` or `:bottom`; also the padding side of the content
  # @param align [Symbol] `:left`, `:center` or `:right`
  # @param layout [Symbol] `:horizontal` or `:vertical`
  # @param icon_size [Numeric] accepted for parity with recharts, ignored by the shadcn content
  # @param icon_type [Symbol, nil] accepted and ignored
  # @param inactive_color [String, nil] accepted and ignored (recharts' default is a light gray, used only by its default content)
  # @param item_sorter [Symbol, nil] `:value` sorts the payload by name, nil keeps the series order
  # @param width [Numeric, nil] width of the wrapper
  # @param height [Numeric, nil] height of the wrapper
  # @param payload_uniq_by [Boolean] unique payload by `value`
  # @param wrapper_style [Hash, String, nil] style of the `recharts-legend-wrapper` div
  # @param legend_height [Numeric] server assumption for the measured height of the content (`pt-3` plus a 16px line)
  # @param attrs [Hash] attributes of the `recharts-legend-wrapper` div (a chadcn addition); `class:` is merged
  # @raise [ArgumentError] on a `vertical_align:` outside the three alignments, or a `content:` that is not a legend content
  def initialize(content: nil, vertical_align: :bottom, align: :center, layout: :horizontal, icon_size: 14, icon_type: nil,
                 inactive_color: nil, item_sorter: :value, width: nil, height: nil, payload_uniq_by: false, wrapper_style: nil,
                 legend_height: 28, **attrs)
    unless ALIGNMENTS.include?(vertical_align&.to_sym)
      raise ArgumentError, "vertical_align: must be one of #{ALIGNMENTS.map(&:inspect).join(', ')} (got #{vertical_align.inspect})"
    end
    unless content.nil? || content.is_a?(Chadcn::Chart::Legend::Content)
      raise ArgumentError, "content: must be a Chadcn::Chart::Legend::Content (got #{content.class})"
    end

    @content_element = content
    @options = {
      vertical_align: vertical_align.to_sym, align: align, layout: layout, icon_size: icon_size, icon_type: icon_type,
      inactive_color: inactive_color, item_sorter: item_sorter, width: width, height: height, payload_uniq_by: payload_uniq_by,
      wrapper_style: wrapper_style, legend_height: legend_height, attrs: attrs
    }.freeze
    super()
  end

  # A declaration renders nothing where it is written; the chart that contains it draws the legend.
  #
  # @return [void]
  def view_template; end

  # Nested in this file, not in `legend/content.rb`: `Base.const_added` loads the parts of `Chart` while Zeitwerk is still
  # registering them, before it can hook the namespace of a file that also has a directory, so a `legend/` directory
  # would stay unregistered (epic chart, item #45).
  # shadcn `ChartLegendContent`: the legend of a chart, rendered from a payload (one item per series) and the config of the enclosing
  # {Chadcn::Chart::Container}. Renders nothing for an empty payload; items of type `none` are skipped.
  #
  # Declare it on a {Chadcn::Chart::Legend} (`content:`); the chart renders it with the series payload. A payload item is a Hash:
  # `value:` (name), `data_key:`, `color:`, `type:`. Inside a `Legend` the padding side follows the Legend's own `vertical_align`.
  #
  # @example
  #   render Chadcn::Chart::Legend::Content.new(payload: [ { data_key: "desktop", color: "var(--color-desktop)" } ])
  class Content < Chadcn::Base
    ITEM_CLASSES = "flex items-center gap-1.5 [&>svg]:h-3 [&>svg]:w-3 [&>svg]:text-muted-foreground"
    private_constant :ITEM_CLASSES

    # @param hide_icon [Boolean] show the color dot even where the config has an icon
    # @param vertical_align [Symbol, String] `:top` pads below (`pb-3`), anything else above (`pt-3`)
    # @param name_key [String, Symbol, nil] the payload key whose value names the config entry of an item
    # @param payload [Array<Hash>] the series
    # @param attrs [Hash] attributes of the root div; `class:` is merged last
    def initialize(hide_icon: false, vertical_align: :bottom, name_key: nil, payload: [], **attrs)
      @options = { hide_icon: hide_icon, vertical_align: vertical_align, name_key: name_key, **attrs }.freeze
      @hide_icon = hide_icon
      @vertical_align = vertical_align.to_s
      @name_key = name_key
      @payload = payload || []
      @attrs = attrs
      super()
    end

    # A copy with other options, e.g. the payload and the Legend's `vertical_align`.
    #
    # @api private
    # @return [Chadcn::Chart::Legend::Content]
    def with(**changes) = self.class.new(**@options, payload: @payload, **changes)

    # @return [void]
    def view_template
      return if @payload.empty?

      config = chart_config
      classes = [ "flex items-center justify-center gap-4", @vertical_align == "top" ? "pb-3" : "pt-3" ]
      div(**merge_attrs({ class: classes.join(" ") }, @attrs)) do
        @payload.each do |item|
          next if item_value(item, :type).to_s == "none"

          render_item(config.payload_config(item, (@name_key || item_value(item, :data_key) || "value").to_s), item)
        end
      end
    end

    private

    def chart_config
      container = Chadcn::Chart::Container.current(context)
      raise ArgumentError, "#{self.class.name} has no Chart::Container around it; React's useChart() raises the same" unless container

      container.config
    end

    def render_item(item_config, item)
      div(class: cn(ITEM_CLASSES)) do
        icon = item_config&.icon
        if icon && !@hide_icon
          render(icon.is_a?(Phlex::SGML) ? icon : Chadcn::Icon.new(icon))
        else
          div(class: "h-2 w-2 shrink-0 rounded-[2px]", style: "background-color: #{item_value(item, :color)};")
        end
        label = item_config&.label
        unless label.nil?
          label.is_a?(Phlex::SGML) ? render(label) : plain(label.to_s)
        end
      end
    end

    def item_value(item, key)
      item.fetch(key) { item[key.to_s] }
    end
  end
end

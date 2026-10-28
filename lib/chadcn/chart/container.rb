# frozen_string_literal: true

# shadcn `ChartContainer`: the `div[data-slot="chart"]` that holds a chart, with the chart classes of the oracle, the
# {Chadcn::Chart::Style} for the config colors and the `recharts-responsive-container` shell recharts' `ResponsiveContainer` writes.
# It yields itself and, while the block runs, offers itself to the shadcn contents and the chart roots through the render context
# ({.current}), which is what React's `ChartContext` does.
#
# The chart is laid out once at `initial_dimension` (320x200 by default) and does not follow the size of its container; the host
# sizes it with this keyword (dev/port/deviations/chart.json). `**attrs` land on the div (`class:` merged last); every Stimulus
# value of `chadcn--chart` goes here too.
#
# @example
#   render Chadcn::Chart::Container.new(config: { desktop: { label: "Desktop", color: "var(--chart-1)" } }) do |container|
#     # render a Chadcn::Chart::BarChart here
#   end
class Chadcn::Chart::Container < Chadcn::Base
  # `INITIAL_DIMENSION` of `chart.tsx`.
  DEFAULT_DIMENSION = { width: 320, height: 200 }.freeze

  # Key of the render context the container publishes itself under.
  #
  # @api private
  CONTEXT_KEY = :chadcn_chart_container

  CLASSES = "flex aspect-video justify-center text-xs [&_.recharts-cartesian-axis-tick_text]:fill-muted-foreground " \
            "[&_.recharts-cartesian-grid_line[stroke='#ccc']]:stroke-border/50 [&_.recharts-curve.recharts-tooltip-cursor]:stroke-border " \
            "[&_.recharts-dot[stroke='#fff']]:stroke-transparent [&_.recharts-layer]:outline-hidden " \
            "[&_.recharts-polar-grid_[stroke='#ccc']]:stroke-border [&_.recharts-radial-bar-background-sector]:fill-muted " \
            "[&_.recharts-rectangle.recharts-tooltip-cursor]:fill-muted [&_.recharts-reference-line_[stroke='#ccc']]:stroke-border " \
            "[&_.recharts-sector]:outline-hidden [&_.recharts-sector[stroke='#fff']]:stroke-transparent [&_.recharts-surface]:outline-hidden"
  private_constant :CLASSES

  # @return [Chadcn::Chart::Config]
  attr_reader :config
  # @return [String] the value of `data-chart` and of the {Chadcn::Chart::Style} selector, `chart-<id>`
  attr_reader :chart_id
  # @return [Hash{Symbol => Numeric}] `width` and `height` the chart is laid out at
  attr_reader :initial_dimension
  # @return [Numeric] server assumption for the height of a line of tick text (`chadcn--chart` re-measures)
  attr_reader :text_height
  # @return [Numeric] server assumption for the width of a character in em
  attr_reader :text_char_width

  # Adds markup after the responsive shell, as the last children of the `div[data-slot="chart"]` (what a chart inside writes there: the inert
  # tooltip templates `chadcn--chart` swaps in, dev/port/specs/chart.md "Tooltip"). Call it while the container's block runs.
  #
  # @api private
  # @param markup [String] HTML the caller already escaped
  # @return [void]
  def append_after_shell(markup) = (@after_shell ||= +"") << markup

  # The container the current render is inside, or nil. Used by the contents and the chart roots (React's `useChart`).
  #
  # @api private
  # @param context [Hash] the Phlex render context
  # @return [Chadcn::Chart::Container, nil]
  def self.current(context) = context[CONTEXT_KEY]

  # @param config [Hash, Chadcn::Chart::Config] see {Chadcn::Chart::Config}
  # @param id [String, Symbol, nil] names the chart (`data-chart="chart-<id>"`); a random token when nil, which makes every render
  #   different: pass `id:` where the output is cached, morphed or compared
  # @param initial_dimension [Hash] `width:` and `height:` in px
  # @param text_height [Numeric]
  # @param text_char_width [Numeric]
  # @param attrs [Hash] attributes of the div; `class:` is merged last
  # @raise [ArgumentError] on an invalid id, config or dimension
  def initialize(config:, id: nil, initial_dimension: DEFAULT_DIMENSION, text_height: 16, text_char_width: 0.6, **attrs)
    @config = Chadcn::Chart::Config.new(config)
    @chart_id = "chart-#{validated_chart_id(id)}"
    @initial_dimension = validated_dimension(initial_dimension)
    @text_height = validated_measure(:text_height, text_height)
    @text_char_width = validated_measure(:text_char_width, text_char_width)
    @attrs = attrs
    super()
  end

  # @yieldparam container [Chart::Container] itself
  # @return [void]
  def view_template
    div(**merge_attrs({ data: { slot: "chart", chart: @chart_id }, class: CLASSES }, @attrs)) do
      render Chadcn::Chart::Style.new(id: @chart_id, config: @config)
      div(class: "recharts-responsive-container", style: "width: 100%; height: 100%; min-width: 0px;") do
        div(style: "width: 0px; height: 0px; overflow: visible;") { publish { |container| yield container if block_given? } }
      end
      raw(safe(@after_shell)) if @after_shell
    end
  end

  private

  def publish
    previous = context[CONTEXT_KEY]
    context[CONTEXT_KEY] = self
    yield self
  ensure
    previous ? context[CONTEXT_KEY] = previous : context.delete(CONTEXT_KEY)
  end

  def validated_chart_id(id)
    name = validated_id(id)
    return SecureRandom.alphanumeric(8).downcase unless name
    return name if Chadcn::Chart::Config.style_token?(name)

    raise ArgumentError, "id: must be letters, digits, _ and - (it becomes data-chart and a style selector), got #{id.inspect}"
  end

  def validated_dimension(dimension)
    width, height = dimension.is_a?(Hash) ? [ dimension[:width] || dimension["width"], dimension[:height] || dimension["height"] ] : []
    unless measure?(width) && measure?(height)
      raise ArgumentError, "initial_dimension: needs a positive width: and height: (got #{dimension.inspect})"
    end

    { width: width, height: height }.freeze
  end

  def validated_measure(name, value)
    return value if measure?(value)

    raise ArgumentError, "#{name}: must be a positive finite number (got #{value.inspect})"
  end

  def measure?(value) = value.is_a?(Numeric) && value.real? && value.finite? && value.positive?
end

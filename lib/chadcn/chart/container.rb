# frozen_string_literal: true

# shadcn `ChartContainer`: the `div[data-slot="chart"]` that holds a chart, with the chart classes of the oracle, the
# {Chadcn::Chart::Style} for the config colors and the `recharts-responsive-container` shell recharts' `ResponsiveContainer` writes.
# It yields itself and, while the block runs, offers itself to the shadcn contents and the chart roots through the render context
# ({.current}), which is what React's `ChartContext` does.
#
# The chart is laid out on the server at `initial_dimension` (320x200 by default). Without `relayout_url:` it keeps that size whatever its
# container does (dev/port/deviations/chart.json). With `relayout_url:` (a same-origin URL that answers with this chart) `chadcn--chart`
# follows the size of the container like recharts' `ResponsiveContainer`: once the box has settled at another size it requests the chart
# from that URL at the measured size and swaps it in; the host reads the request with {.relayout_options} (dev/port/specs/chart.md,
# "Behavior", "Resize and re-measure"). `**attrs` land on the div (`class:` merged last). The div is the element of the Stimulus
# controller `chadcn--chart` (always, so a Turbo-streamed container is wired too) and carries every value of it: the chart inside hands
# them over ({#publish_chart_values}), Stimulus reads values from the controller element only.
#
# @example
#   render Chadcn::Chart::Container.new(config: { desktop: { label: "Desktop", color: "var(--chart-1)" } }) do |container|
#     # render a Chadcn::Chart::BarChart here
#   end
# @example A chart that follows its container (the action renders the same chart for the request)
#   render Chadcn::Chart::Container.new(config: config, id: "sales", class: "h-64 w-full", relayout_url: sales_chart_path,
#                                       **Chadcn::Chart::Container.relayout_options(params, id: "sales")) do
#     # render the chart here
#   end
class Chadcn::Chart::Container < Chadcn::Base
  # `INITIAL_DIMENSION` of `chart.tsx`.
  DEFAULT_DIMENSION = { width: 320, height: 200 }.freeze

  # Key of the render context the container publishes itself under.
  #
  # @api private
  CONTEXT_KEY = :chadcn_chart_container

  CONTROLLER = "chadcn--chart"

  CLASSES = "flex aspect-video justify-center text-xs [&_.recharts-cartesian-axis-tick_text]:fill-muted-foreground " \
            "[&_.recharts-cartesian-grid_line[stroke='#ccc']]:stroke-border/50 [&_.recharts-curve.recharts-tooltip-cursor]:stroke-border " \
            "[&_.recharts-dot[stroke='#fff']]:stroke-transparent [&_.recharts-layer]:outline-hidden " \
            "[&_.recharts-polar-grid_[stroke='#ccc']]:stroke-border [&_.recharts-radial-bar-background-sector]:fill-muted " \
            "[&_.recharts-rectangle.recharts-tooltip-cursor]:fill-muted [&_.recharts-reference-line_[stroke='#ccc']]:stroke-border " \
            "[&_.recharts-sector]:outline-hidden [&_.recharts-sector[stroke='#fff']]:stroke-transparent [&_.recharts-surface]:outline-hidden"
  private_constant :CLASSES, :CONTROLLER

  # The two divs recharts' `ResponsiveContainer` writes around the chart (component/ResponsiveContainer.js), shared with a chart that has no
  # container around it.
  #
  # @api private
  SHELL_STYLE = "width: 100%; height: 100%; min-width: 0px;"
  # @api private
  INNER_STYLE = "width: 0px; height: 0px; overflow: visible;"

  # @return [Chadcn::Chart::Config]
  attr_reader :config
  # @return [String] the value of `data-chart` and of the {Chadcn::Chart::Style} selector, `chart-<id>`
  attr_reader :chart_id
  # @return [Hash{Symbol => Numeric}] `width` and `height` the chart is laid out at
  attr_reader :initial_dimension
  # @return [Numeric] server assumption for the height of a line of tick text (not re-measured in the browser)
  attr_reader :text_height
  # @return [Numeric] server assumption for the width of a character in em
  attr_reader :text_char_width
  # @return [String, nil] where `chadcn--chart` requests this chart at the size of its container; nil when it keeps `initial_dimension`
  attr_reader :relayout_url

  # Largest `width` and `height` {.relayout_options} accepts, in px (dev/port/specs/chart.md, "Resize and re-measure").
  RELAYOUT_MAX_SIZE = 4096
  # Bounds of the text metrics {.relayout_options} accepts.
  RELAYOUT_METRIC_BOUNDS = { text_height: 256, text_char_width: 4 }.freeze
  # A request parameter is a plain decimal number (no hex, no `Infinity`).
  RELAYOUT_NUMBER = /\A\d+(?:\.\d+)?(?:e[+-]?\d+)?\z/i
  private_constant :RELAYOUT_NUMBER

  # Adds a component after the responsive shell, rendered as the last children of the `div[data-slot="chart"]` (what a chart inside writes
  # there: the inert tooltip templates `chadcn--chart` swaps in, dev/port/specs/chart.md "Tooltip"). Call it while the container's block runs.
  #
  # @api private
  # @param part [Phlex::SGML] the component to render
  # @return [void]
  # @raise [ArgumentError] on anything that is not a Phlex component
  def append_after_shell(part)
    raise ArgumentError, "append_after_shell takes a Phlex component (got #{part.class})" unless part.is_a?(Phlex::SGML)

    @after_shell << part
  end

  # The container holds one chart: `chadcn--chart` reads one set of templates and one config scope.
  #
  # @api private
  # @param chart [Object] the chart root about to render inside
  # @return [void]
  # @raise [ArgumentError] when a chart already claimed the container
  def claim_chart(chart)
    raise ArgumentError, "a Chart::Container holds one chart (got a second #{chart.class.name})" if @chart

    @chart = chart
  end

  # The values of the `chadcn--chart` controller the chart inside computed (layout, ticks, tooltip options ...), written on the div.
  #
  # @api private
  # @param values [Hash{Symbol => Object}] data attributes (`chadcn__chart_layout_value: "horizontal"`)
  # @return [void]
  # @param legend_height [Numeric, nil] the height of the chart's legend box, written into the `textMetrics` value; nil without a legend
  def publish_chart_values(values, legend_height: nil)
    @chart_values = values
    @legend_height = legend_height
  end

  # The container keywords for the re-layout request `chadcn--chart` sends to `relayout_url:` (query parameters `chart[id]`,
  # `chart[width]`, `chart[height]`, `chart[text_height]`, `chart[text_char_width]`), for the chart named `id:`; splat it into `new`.
  # Only the keys present come back, each a positive finite number within its bound (`width` and `height` at most {RELAYOUT_MAX_SIZE},
  # `text_height` at most 256, `text_char_width` at most 4); `initial_dimension:` needs both `width` and `height`. A request for
  # another chart, or no request, gives `{}`: the chart renders at its own defaults. `params` is read with `[]` only (string or symbol
  # keys), so a Hash and unpermitted `ActionController::Parameters` both work. `chart[legend_height]` is not read yet: the
  # re-measure item adds `legend_height:` to the container.
  #
  # @param params [#[], nil] the request parameters
  # @param id [String, Symbol] the container's `id:`
  # @return [Hash{Symbol => Object}]
  # @example
  #   Chadcn::Chart::Container.relayout_options({ "chart" => { "id" => "sales", "width" => "640", "height" => "400" } }, id: "sales")
  #   # => { initial_dimension: { width: 640, height: 400 } }
  def self.relayout_options(params, id:)
    chart = relayout_param(params, :chart)
    return {} unless chart.respond_to?(:[]) && !chart.is_a?(String) && relayout_param(chart, :id).to_s == id.to_s

    width, height = %i[width height].map { |key| relayout_number(relayout_param(chart, key), RELAYOUT_MAX_SIZE) }
    options = width && height ? { initial_dimension: { width: width, height: height } } : {}
    RELAYOUT_METRIC_BOUNDS.each_with_object(options) do |(key, bound), result|
      value = relayout_number(relayout_param(chart, key), bound)
      result[key] = value if value
    end
  end

  # @api private
  def self.relayout_param(params, key)
    return unless params.respond_to?(:[]) && !params.is_a?(String) && !params.is_a?(Array)

    value = params[key.to_s]
    value.nil? ? params[key] : value
  rescue TypeError, ArgumentError
    nil
  end
  private_class_method :relayout_param

  # @api private
  def self.relayout_number(value, bound)
    number = case value
             when Integer, Float then value
             when String then Float(value) if RELAYOUT_NUMBER.match?(value)
             end
    return unless number&.finite? && number.positive? && number <= bound

    number == number.to_i ? number.to_i : number
  end
  private_class_method :relayout_number

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
  # @param relayout_url [String, nil] a same-origin URL that answers with this chart (see {.relayout_options}); nil keeps
  #   `initial_dimension` whatever the size of the container
  # @param attrs [Hash] attributes of the div; `class:` is merged last
  # @raise [ArgumentError] on an invalid id, config or dimension
  def initialize(config:, id: nil, initial_dimension: DEFAULT_DIMENSION, text_height: 16, text_char_width: 0.6, relayout_url: nil, **attrs)
    @config = Chadcn::Chart::Config.new(config)
    @chart_id = "chart-#{validated_chart_id(id)}"
    @initial_dimension = validated_dimension(initial_dimension)
    @text_height = validated_measure(:text_height, text_height)
    @text_char_width = validated_measure(:text_char_width, text_char_width)
    @relayout_url = validated_relayout_url(relayout_url)
    @attrs = attrs
    @after_shell = []
    @chart = nil
    @chart_values = {}
    @legend_height = nil
    super()
  end

  # @yieldparam container [Chart::Container] itself
  # @return [void]
  def view_template
    # The chart inside decides the values of the div, which opens before its children: the block runs first.
    body = capture { publish { |container| yield container if block_given? } }
    data = { slot: "chart", chart: @chart_id, controller: CONTROLLER, **@chart_values, **relayout_values }
    div(**merge_attrs({ data: data, class: CLASSES }, @attrs)) do
      render Chadcn::Chart::Style.new(id: @chart_id, config: @config)
      div(class: "recharts-responsive-container", style: SHELL_STYLE) { div(style: INNER_STYLE) { raw safe(body) } }
      publish { @after_shell.each { |part| render part } }
    end
  end

  private

  # The values of the re-layout (dev/port/specs/chart.md, "Resize and re-measure"), only with a `relayout_url:`: without one the div is
  # what 0.1.0 rendered.
  def relayout_values
    return {} unless @relayout_url

    metrics = { textHeight: @text_height, textCharWidth: @text_char_width }
    metrics[:legendHeight] = @legend_height if @legend_height
    { chadcn__chart_relayout_url_value: @relayout_url, chadcn__chart_dimension_value: json(@initial_dimension),
      chadcn__chart_text_metrics_value: json(metrics) }
  end

  def validated_relayout_url(url)
    return if url.nil?
    return url if url.is_a?(String) && !url.strip.empty?

    raise ArgumentError, "relayout_url: must be a non-empty String (got #{url.inspect})"
  end

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

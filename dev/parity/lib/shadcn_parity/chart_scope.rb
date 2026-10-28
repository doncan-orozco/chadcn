# frozen_string_literal: true

using Chadcn::Values::Refinements

# The chart half of the parity harness (dev/port/specs/chart.md, "Oracle driving"). Mirror of the chart code of
# dev/react-shadcn-catalog/src/parity/Harness.tsx (`chartProps`, `reviveFormatters`): the recharts parts are `_`-prefixed nodes
# (`_BarChart`, `_Bar`, ...) resolved to `Chadcn::Chart::*`, `content: "ChartTooltipContent"` (+ `contentProps`) becomes the content
# instance, and `{ "formatter": "slice", "args": [0, 3] }` becomes the named formatter the chart classes accept.
module ShadcnParity::ChartScope
  # The recharts exports a scenario reaches as `_<Name>` that the gem ports (the polar ones join as their items land).
  RECHARTS_PARTS = %w[
    BarChart LineChart AreaChart Bar Line Area Cell XAxis YAxis CartesianGrid LabelList Label ReferenceLine
  ].freeze
  # The nodes whose props are chart props: the parts above, the shadcn layer that takes a `content`.
  CHART_NODES = (RECHARTS_PARTS.map { |name| "_#{name}" } + %w[ChartTooltip ChartLegend]).freeze
  # `content: <name>` on the oracle side is a React element; here the instance of its class.
  CONTENTS = { "ChartTooltipContent" => "Tooltip", "ChartLegendContent" => "Legend" }.freeze
  # The SVG a chart's block writes itself (a gradient for an area), drawn inside the chart's svg.
  SVG_NODES = %w[_defs _linearGradient _radialGradient _stop].freeze
  # The height of one line of text in the harness page: recharts measures a tick label in a span under `body` (the page font, not the
  # chart's `text-xs`), the server has to assume it (`Chart::Container text_height:`); it decides how far the last tick of a vertical
  # axis is pulled inside the plot (recharts:cartesian/getTicks.js, `getTicksEnd`).
  PAGE_TEXT_HEIGHT = 18
  # Props that are data, not options: their keys are the caller's, kept as they are.
  DATA_PROPS = %w[data].freeze

  private

  def harness_scope(bare)
    return [ Chadcn::Chart, bare, RECHARTS_PARTS ] if RECHARTS_PARTS.include?(bare)

    super
  end

  # Chart nodes only; every other node reads its props as before.
  def render_node(node, roots)
    return render_svg(node, roots) if SVG_NODES.include?(node["c"])
    return super(node.merge("props" => container_props(node["props"] || {})), roots) if node["c"] == "ChartContainer"
    return super unless CHART_NODES.include?(node["c"])

    super(node.merge("props" => revive_chart_props(node["props"] || {})), roots)
  end

  def render_svg(node, roots)
    attributes = (node["props"] || {}).to_h { |key, value| [ key.snake_case.to_sym, value ] }
    render(ShadcnParity::SvgElement.new(node["c"].delete_prefix("_"), **attributes)) { render_children(node["children"], roots) }
  end

  def container_props(props) = props.key?("textHeight") ? props : props.merge("textHeight" => PAGE_TEXT_HEIGHT)

  def revive_chart_props(props)
    content_props = props["contentProps"] || {}
    revived = props.except("contentProps").to_h { |key, value| [ key, DATA_PROPS.include?(key) ? value : revive(value) ] }
    kind = CONTENTS[revived["content"]]
    revived["content"] = Chadcn::Chart.const_get(kind).const_get(:Content).new(**content_kwargs(content_props)) if kind
    revived
  end

  def content_kwargs(props)
    props.to_h { |key, value| [ key.snake_case.to_sym, revive(value) ] }
  end

  # A named formatter becomes `{ slice: [from, to] }`, `:locale` or `:percent`; hashes keep their keys as symbols, in snake case
  # (`strokeWidth` is `stroke_width`), so `{"top": 5}` is `{ top: 5 }`.
  def revive(value)
    case value
    when Array then value.map { |element| revive(element) }
    when Hash then named_formatter(value) || value.to_h { |key, element| [ key.to_s.snake_case.to_sym, revive(element) ] }
    else value
    end
  end

  def named_formatter(value)
    return unless value["formatter"].is_a?(String)

    name = value["formatter"]
    name == "slice" ? { slice: Array(value["args"]) } : name.to_sym
  end
end

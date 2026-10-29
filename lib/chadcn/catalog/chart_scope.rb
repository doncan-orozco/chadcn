# frozen_string_literal: true

using Chadcn::Values::Refinements

# The chart half of {Chadcn::Catalog::TreeRenderer} (dev/port/specs/chart.md, "Oracle driving"); the renderer prepends it. Mirror of the
# chart code of dev/react-shadcn-catalog/src/parity/Harness.tsx (`chartProps`, `reviveFormatters`): the recharts parts are `_`-prefixed
# nodes (`_BarChart`, `_Bar`, ...) resolved to `Chadcn::Chart::*`, `content: "ChartTooltipContent"` (+ `contentProps`) becomes the content
# instance, a node `ChartTooltipContent` / `ChartLegendContent` on its own is that content, and `{ "formatter": "slice", "args": [0, 3] }`
# becomes the named formatter the chart classes accept.
#
# It is prepended to the renderer and relies on the host's `render_node`, `render_children`, `render` and `harness_scope`.
#
# @api private
module Chadcn::Catalog::ChartScope
  # The recharts exports a scenario reaches as `_<Name>` that the gem ports.
  RECHARTS_PARTS = %w[
    BarChart LineChart AreaChart PieChart RadarChart RadialBarChart Bar Line Area Pie Radar RadialBar Cell XAxis YAxis CartesianGrid PolarGrid
    PolarAngleAxis PolarRadiusAxis LabelList Label ReferenceLine
  ].freeze
  # The nodes whose props are chart props: the parts above, the shadcn layer that takes a `content`.
  CHART_NODES = (RECHARTS_PARTS.map { |name| "_#{name}" } + %w[ChartTooltip ChartLegend]).to_set.freeze
  # `content: <name>` is a React element in the oracle; here the instance of its class.
  CONTENTS = { "ChartTooltipContent" => "Tooltip", "ChartLegendContent" => "Legend" }.freeze
  # The SVG a chart's block writes itself (a gradient for an area), drawn inside the chart's svg.
  SVG_NODES = Chadcn::Catalog::SvgElement::TAGS.to_set { |tag| "_#{tag}" }.freeze
  # Props that are data, not options: their keys are the caller's, kept as they are.
  DATA_PROPS = %w[data].freeze
  # React's spelling of the SVG props a scenario writes, to the attribute react-dom writes; any other prop keeps its spelling as react-dom writes it.
  SVG_ATTRIBUTES = { "className" => "class", "stopColor" => "stop-color", "stopOpacity" => "stop-opacity", "xlinkHref" => "xlink:href" }.freeze
  # The recharts parts the renderer resolves itself, as node names.
  RESOLVABLE = RECHARTS_PARTS.to_set { |part| "_#{part}" }.freeze
  private_constant :CHART_NODES, :CONTENTS, :SVG_NODES, :DATA_PROPS, :SVG_ATTRIBUTES, :RESOLVABLE

  # @param name [String] a node name as a scenario writes it (`"_BarChart"`)
  # @return [Boolean] whether the renderer resolves it itself (a recharts part), so it is not a node only the parity harness knows
  def self.resolvable_node?(name) = RESOLVABLE.include?(name)

  private

  def harness_scope(bare)
    return [ Chadcn::Chart, bare, RECHARTS_PARTS ] if Chadcn::Catalog::ChartScope.resolvable_node?("_#{bare}")

    super
  end

  # Chart nodes only; every other node reads its props as before.
  def render_node(node, roots)
    return render_svg(node, roots) if SVG_NODES.include?(node["c"])
    return render_content(node) if CONTENTS.key?(node["c"])
    return super unless CHART_NODES.include?(node["c"])

    super(node.merge("props" => revive_chart_props(node["props"] || {})), roots)
  end

  def render_svg(node, roots)
    attributes = (node["props"] || {}).to_h { |key, value| [ SVG_ATTRIBUTES.fetch(key, key).to_sym, value ] }
    render(Chadcn::Catalog::SvgElement.new(node["c"].delete_prefix("_"), **attributes)) { render_children(node["children"], roots) }
  end

  # A content node on its own (`<ChartTooltipContent active payload=... />` under the container); React's `active: false` renders nothing.
  def render_content(node)
    props = node["props"] || {}
    return if props["active"] == false

    render content_instance(node["c"], props.except("active"))
  end

  def revive_chart_props(props)
    revived = props.except("contentProps").to_h { |key, value| [ key, DATA_PROPS.include?(key) ? value : revive(value) ] }
    revived["content"] = content_instance(revived["content"], props["contentProps"] || {}) if CONTENTS.key?(revived["content"])
    revived
  end

  def content_instance(name, props)
    Chadcn::Chart.const_get(CONTENTS.fetch(name)).const_get(:Content).new(**props.to_h { |key, value| [ key.snake_case.to_sym, revive(value) ] })
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

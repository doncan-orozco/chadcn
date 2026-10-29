# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- cx and cy are the center vocabulary of recharts

# What `Chart::PieChart`, `Chart::RadarChart` and `Chart::RadialBarChart` share (recharts' `PolarChart`, chart/PolarChart.js). The block of
# the chart is run first, collecting the declarations; one layout pass then places everything ({Chadcn::Chart::Polar::Layout}), and the
# SVG is drawn from the result ({Chadcn::Chart::Polar::Surface}) in recharts' own markup: `div.recharts-wrapper > svg.recharts-surface`
# with one `g` per z-index layer.
#
# The chart is laid out once, at the size of the enclosing {Chadcn::Chart::Container} (`initial_dimension`, 320x200 without one); it does
# not follow the size of its box.
#
# @api private
class Chadcn::Chart::Polar::Root < Chadcn::Base
  include Chadcn::Chart::Declarations
  include Chadcn::Chart::Cartesian::Choice

  DEFAULT_MARGIN = { top: 5, right: 5, bottom: 5, left: 5 }.freeze
  # The size recharts lays a chart out at when nothing measures it (`INITIAL_DIMENSION` of chart.tsx).
  DEFAULT_DIMENSION = { width: 320, height: 200 }.freeze

  private_constant :DEFAULT_MARGIN, :DEFAULT_DIMENSION

  # @api private
  # @param data [Array<Hash>] one row per category
  # @param margin [Hash] `top:`, `right:`, `bottom:` and `left:`; a side that is not given is 0, as in recharts
  # @param start_angle [Numeric] degrees, counterclockwise from 3 o'clock
  # @param end_angle [Numeric] degrees; below `start_angle` the chart runs clockwise
  # @param cx [Numeric, String] center x, px or a percent of the chart width
  # @param cy [Numeric, String] center y, px or a percent of the chart height
  # @param inner_radius [Numeric, String] px or a percent of the largest circle in the plot
  # @param outer_radius [Numeric, String] px or a percent of the largest circle in the plot
  # @param bar_category_gap [Numeric, String] space around the bars of a category, a number or a percent of the band
  # @param bar_gap [Numeric, String] space between the bars of a category
  # @param bar_size [Numeric, String, nil] thickness of a bar
  # @param max_bar_size [Numeric, nil] thickest a bar may be
  # @param accessibility_layer [Boolean] `role="application"` and `tabindex="0"` on the svg
  # @param title [String, nil] text of the svg `title`
  # @param desc [String, nil] text of the svg `desc`
  # @param role [String, nil] replaces `application`
  # @param tab_index [Integer, nil] replaces `0`
  # @param attrs [Hash] `class:` and `style:` go on `.recharts-wrapper`, every other attribute on the svg
  def initialize(start_angle:, end_angle:, data: [], margin: DEFAULT_MARGIN, cx: "50%", cy: "50%", inner_radius: 0, outer_radius: "80%",
                 bar_category_gap: "10%", bar_gap: 4, bar_size: nil, max_bar_size: nil, accessibility_layer: true, title: nil, desc: nil, role: nil,
                 tab_index: nil, **attrs)
    load_declarations
    raise ArgumentError, "data: must be an Array of Hashes (got #{data.class})" unless data.is_a?(Array) && data.all?(Hash)
    raise ArgumentError, "margin: must be a Hash (got #{margin.class})" unless margin.is_a?(Hash)

    { start_angle: start_angle, end_angle: end_angle }.each { |name, angle| number!(name, angle) }
    { cx: cx, cy: cy, inner_radius: inner_radius, outer_radius: outer_radius }.each { |name, share| share!(name, share) }
    @options = { data: data, margin: margin, start_angle: start_angle, end_angle: end_angle, cx: cx, cy: cy, inner_radius: inner_radius,
                 outer_radius: outer_radius, bar_category_gap: bar_category_gap, bar_gap: bar_gap, bar_size: bar_size, max_bar_size: max_bar_size,
                 accessibility_layer: accessibility_layer, title: title, desc: desc, role: role, tab_index: tab_index, attrs: attrs }.freeze
    super()
  end

  # Registers a declaration written directly in the chart's block.
  #
  # @api private
  # @param declaration [Object]
  # @return [void]
  def declare(declaration) = @declared.declare(declaration)

  # @yieldparam chart [Chadcn::Chart::Polar::Root] itself, offering the helper of every declaration
  # @return [void]
  def view_template(&)
    @declared = Chadcn::Chart::Polar::Declared.new(chart: self.class)
    markup = collect(&)
    container = Chadcn::Chart::Container.current(context)
    container&.claim_chart(self)
    layout = Chadcn::Chart::Polar::Layout.new(@declared, layout_settings(container))
    plan = Chadcn::Chart::Polar::TooltipPlan.new(layout: layout, declared: @declared, rows: layout.rows) if @declared.tooltip
    append_tooltip_templates(container, plan) if plan
    within_responsive_shell(container) do
      div(**wrapper_attributes(layout)) do
        render Chadcn::Chart::Polar::Overlays.new(layout: layout, declared: @declared, plan: plan)
        render surface(layout, container, markup, plan)
      end
    end
  end

  private

  # A chart's block calls the helpers of the declaration classes (`chart.pie`), which `Chadcn::Chart::Declaration.inherited` defines as each
  # class loads. Zeitwerk may have tried to load a part before the classes it needs were registered (it registers them in alphabetical order)
  # and left it for later, so the whole family is loaded when a chart is built (a constant being loaded right now is not autoloadable).
  def load_declarations
    Chadcn::Chart.constants(false).each { |name| Chadcn::Chart.const_get(name, false) if Chadcn::Chart.autoload?(name, false) }
  end

  def number!(name, value)
    raise ArgumentError, "#{name}: must be a number of degrees (got #{value.inspect})" unless value.is_a?(Numeric) && value.real? && value.finite?
  end

  def share!(name, value)
    return if value.is_a?(Numeric) || (value.is_a?(String) && value.match?(/\A\s*[+-]?(?:\d+\.?\d*|\.\d+)%?\s*\z/))

    raise ArgumentError, "#{name}: must be a number or a percent such as \"50%\" (got #{value.inspect})"
  end

  # Runs the block of the chart with the chart as the scope declarations register with. Whatever markup the block itself writes (a
  # `<defs>` of gradients) is kept, and drawn inside the svg.
  def collect(&block)
    return "" unless block

    Chadcn::Chart::Cartesian::Scope.with(context, self) { capture { yield self } }
  end

  # The inert tooltip templates are children of the container, after its shell (dev/port/specs/chart.md, "Tooltip"). A chart outside a
  # container has no config for the tooltip content to read, so it has no templates either.
  def append_tooltip_templates(container, plan)
    return unless container && plan.tooltip.content_element

    container.append_after_shell(Chadcn::Chart::Cartesian::TooltipTemplates.new(plan: plan))
  end

  def layout_settings(container)
    dimension = container ? container.initial_dimension : DEFAULT_DIMENSION
    text = Chadcn::Chart::Cartesian::Text.new(char_width: container&.text_char_width || 0.6, line_height: container&.text_height || 16)
    Chadcn::Chart::Polar::ChartSettings.new(
      type: self.class::CHART_TYPE, layout: self.class::LAYOUT, width: dimension[:width], height: dimension[:height], margin: @options[:margin],
      rows: @options[:data], text: text, cx: @options[:cx], cy: @options[:cy], inner_radius: @options[:inner_radius],
      outer_radius: @options[:outer_radius], start_angle: @options[:start_angle], end_angle: @options[:end_angle],
      bar_category_gap: @options[:bar_category_gap], bar_gap: @options[:bar_gap], bar_size: @options[:bar_size], max_bar_size: @options[:max_bar_size]
    )
  end

  # A chart outside a container is wrapped the way the container wraps it.
  def within_responsive_shell(container, &block)
    return yield if container

    div(class: "recharts-responsive-container", style: Chadcn::Chart::Container::SHELL_STYLE) do
      div(style: Chadcn::Chart::Container::INNER_STYLE, &block)
    end
  end

  # `.recharts-wrapper` (chart/RechartsWrapper.js:323): the size, and the caller's `class:` and `style:`.
  def wrapper_attributes(layout)
    attrs = @options[:attrs]
    width = Chadcn::Chart::Shape::Number.format(layout.width)
    height = Chadcn::Chart::Shape::Number.format(layout.height)
    style = [ "position: relative; cursor: default; width: #{width}px; height: #{height}px;", attrs[:style] ].compact.join(" ")
    { width: width, height: height, class: cn("recharts-wrapper", attrs[:class]), style: style }
  end

  # The svg takes `cx` and `cy` of the chart as attributes (container/RootSurface.js spreads the chart's SVG props).
  def surface(layout, container, markup, plan)
    attrs = @options[:attrs].except(:class, :style)
    Chadcn::Chart::Polar::Surface.new(
      layout: layout, declared: @declared, markup: markup, tooltip_entry: plan&.default_entry, uid: container&.chart_id || "chart-#{next_sequence(:chart)}",
      frame: { title: @options[:title], desc: @options[:desc], accessibility_layer: @options[:accessibility_layer], role: @options[:role],
               tab_index: @options[:tab_index], attrs: merge_attrs({ cx: @options[:cx].to_s, cy: @options[:cy].to_s }, attrs) }
    )
  end
end

# rubocop:enable Naming/MethodParameterName

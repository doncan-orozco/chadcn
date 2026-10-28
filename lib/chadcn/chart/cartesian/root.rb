# frozen_string_literal: true

# What `Chart::BarChart`, `Chart::LineChart` and `Chart::AreaChart` share (recharts' `CartesianChart`, chart/CartesianChart.js). The
# block of the chart is run first, collecting the declarations; one layout pass then places everything
# ({Chadcn::Chart::Cartesian::Layout}), and the SVG is drawn from the result ({Chadcn::Chart::Cartesian::Surface}) in recharts'
# own markup: `div.recharts-wrapper > svg.recharts-surface` with one `g` per z-index layer.
#
# The chart is laid out once, at the size of the enclosing {Chadcn::Chart::Container} (`initial_dimension`, 320x200 without one); it does
# not follow the size of its box.
#
# @api private
class Chadcn::Chart::Cartesian::Root < Chadcn::Base
  include Chadcn::Chart::Declarations

  LAYOUTS = %i[horizontal vertical].freeze
  STACK_OFFSETS = %i[none expand].freeze
  DEFAULT_MARGIN = { top: 5, right: 5, bottom: 5, left: 5 }.freeze
  # The size recharts lays a chart out at when nothing measures it (`INITIAL_DIMENSION` of chart.tsx).
  DEFAULT_DIMENSION = { width: 320, height: 200 }.freeze

  private_constant :LAYOUTS, :STACK_OFFSETS, :DEFAULT_MARGIN, :DEFAULT_DIMENSION

  # @api private
  # @param data [Array<Hash>] one row per category
  # @param layout [Symbol] `:horizontal` (categories along x) or `:vertical` (along y)
  # @param margin [Hash] `top:`, `right:`, `bottom:` and `left:`; a side that is not given is 0, as in recharts
  # @param bar_category_gap [Numeric, String] space around the bars of a category, a number or a percent of the band
  # @param bar_gap [Numeric, String] space between the bars of a category
  # @param bar_size [Numeric, String, nil] width of a bar
  # @param max_bar_size [Numeric, nil] widest a bar may be
  # @param stack_offset [Symbol] `:none` or `:expand`
  # @param reverse_stack_order [Boolean]
  # @param accessibility_layer [Boolean] `role="application"` and `tabindex="0"` on the svg
  # @param title [String, nil] text of the svg `title`
  # @param desc [String, nil] text of the svg `desc`
  # @param role [String, nil] replaces `application`
  # @param tab_index [Integer, nil] replaces `0`
  # @param attrs [Hash] `class:` and `style:` go on `.recharts-wrapper`, every other attribute on the svg
  def initialize(data: [], layout: :horizontal, margin: DEFAULT_MARGIN, bar_category_gap: "10%", bar_gap: 4, bar_size: nil, max_bar_size: nil,
                 stack_offset: :none, reverse_stack_order: false, accessibility_layer: true, title: nil, desc: nil, role: nil, tab_index: nil,
                 base_value: nil, **attrs)
    load_declarations
    raise ArgumentError, "data: must be an Array of Hashes (got #{data.class})" unless data.is_a?(Array) && data.all?(Hash)
    raise ArgumentError, "margin: must be a Hash (got #{margin.class})" unless margin.is_a?(Hash)

    @options = { data: data, layout: choice(:layout, layout, LAYOUTS), margin: margin, bar_category_gap: bar_category_gap, bar_gap: bar_gap, bar_size: bar_size,
                 max_bar_size: max_bar_size, stack_offset: stack_offset_choice(stack_offset), reverse_stack_order: reverse_stack_order,
                 accessibility_layer: accessibility_layer, title: title, desc: desc, role: role, tab_index: tab_index, base_value: base_value,
                 attrs: attrs }.freeze
    super()
  end

  # Registers a declaration written directly in the chart's block.
  #
  # @api private
  # @param declaration [Object]
  # @return [void]
  def declare(declaration) = @declared.declare(declaration)

  # @yieldparam chart [Chadcn::Chart::Cartesian::Root] itself, offering the helper of every declaration
  # @return [void]
  def view_template(&)
    @declared = Chadcn::Chart::Cartesian::Declared.new
    markup = collect(&)
    container = Chadcn::Chart::Container.current(context)
    layout = Chadcn::Chart::Cartesian::Layout.new(@declared, layout_settings(container))
    plan = Chadcn::Chart::Cartesian::TooltipPlan.new(layout: layout, declared: @declared, rows: @options[:data]) if @declared.tooltip
    append_tooltip_templates(container, plan) if plan
    within_responsive_shell(container) do
      div(**wrapper_attributes(layout)) do
        render Chadcn::Chart::Cartesian::Overlays.new(layout: layout, declared: @declared, plan: plan)
        render surface(layout, container, markup, plan)
      end
    end
  end

  private

  # A chart's block calls the helpers of the declaration classes (`chart.bar`), which `Chadcn::Chart::Declaration.inherited` defines as each
  # class loads. Zeitwerk may have tried to load a part before the classes it needs were registered (it registers them in alphabetical order)
  # and left it for later, so the whole family is loaded when a chart is built (a constant being loaded right now is not autoloadable).
  def load_declarations
    Chadcn::Chart.constants(false).each { |name| Chadcn::Chart.const_get(name, false) if Chadcn::Chart.autoload?(name, false) }
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

    container.append_after_shell(capture { render Chadcn::Chart::Cartesian::TooltipTemplates.new(plan: plan) })
  end

  def layout_settings(container)
    dimension = container ? container.initial_dimension : DEFAULT_DIMENSION
    text = Chadcn::Chart::Cartesian::Text.new(char_width: container&.text_char_width || 0.6, line_height: container&.text_height || 16)
    { type: self.class::CHART_TYPE, direction: @options[:layout], width: dimension[:width], height: dimension[:height], margin: @options[:margin],
      rows: @options[:data], text: text, bar_category_gap: @options[:bar_category_gap], bar_gap: @options[:bar_gap], bar_size: @options[:bar_size],
      max_bar_size: @options[:max_bar_size], stack_offset: @options[:stack_offset], reverse_stack_order: @options[:reverse_stack_order],
      base_value: @options[:base_value] }
  end

  # A chart outside a container is wrapped the way the container wraps it.
  def within_responsive_shell(container, &block)
    return yield if container

    div(class: "recharts-responsive-container", style: "width: 100%; height: 100%; min-width: 0px;") do
      div(style: "width: 0px; height: 0px; overflow: visible;", &block)
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

  def surface(layout, container, markup, plan)
    attrs = @options[:attrs].except(:class, :style)
    Chadcn::Chart::Cartesian::Surface.new(
      layout: layout, declared: @declared, markup: markup, tooltip_entry: plan&.default_entry, uid: container&.chart_id || "chart-#{next_sequence(:chart)}",
      title: @options[:title], desc: @options[:desc], accessibility_layer: @options[:accessibility_layer],
      role: @options[:role], tab_index: @options[:tab_index], attrs: merge_attrs({}, attrs)
    )
  end

  def stack_offset_choice(value)
    choice(:stack_offset, value, STACK_OFFSETS)
  rescue ArgumentError
    raise ArgumentError, "stack_offset: must be one of #{STACK_OFFSETS.map(&:inspect).join(', ')} (got #{value.inspect}; sign, silhouette, wiggle and positive are not ported)"
  end

  def choice(name, value, allowed)
    return value.to_sym if value.respond_to?(:to_sym) && allowed.include?(value.to_sym)

    raise ArgumentError, "#{name}: must be one of #{allowed.map(&:inspect).join(', ')} (got #{value.inspect})"
  end
end

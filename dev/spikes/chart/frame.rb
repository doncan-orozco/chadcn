# frozen_string_literal: true

require "phlex"
require_relative "curve"

module ChartSpike
  # Everything below emits the DOM that recharts 3.8 + the shadcn chart wrapper produce after the browser settles
  # (oracle/*.html). Class strings are copied from the oracle (dev/react-shadcn-catalog/src/components/ui/chart.tsx output).
  CHART_CLASS = "flex aspect-video justify-center text-xs [&_.recharts-cartesian-axis-tick_text]:fill-muted-foreground " \
                "[&_.recharts-cartesian-grid_line[stroke='#ccc']]:stroke-border/50 [&_.recharts-curve.recharts-tooltip-cursor]:stroke-border " \
                "[&_.recharts-dot[stroke='#fff']]:stroke-transparent [&_.recharts-layer]:outline-hidden " \
                "[&_.recharts-polar-grid_[stroke='#ccc']]:stroke-border [&_.recharts-radial-bar-background-sector]:fill-muted " \
                "[&_.recharts-rectangle.recharts-tooltip-cursor]:fill-muted [&_.recharts-reference-line_[stroke='#ccc']]:stroke-border " \
                "[&_.recharts-sector]:outline-hidden [&_.recharts-sector[stroke='#fff']]:stroke-transparent [&_.recharts-surface]:outline-hidden"
  TOOLTIP_CLASS = "grid min-w-[8rem] items-start gap-1.5 rounded-lg border border-border/50 bg-background px-2.5 py-1.5 text-xs shadow-xl"
  TOOLTIP_ITEM_CLASS = "flex w-full flex-wrap gap-2 [&>svg]:h-2.5 [&>svg]:w-2.5 [&>svg]:text-muted-foreground items-center" # after cn()
  TOOLTIP_INDICATOR_CLASS = "shrink-0 rounded-[2px] border-(--color-border) bg-(--color-bg) h-2.5 w-2.5"
  LEGEND_CLASS = "flex items-center justify-center gap-4 pt-3"
  LEGEND_ITEM_CLASS = "flex items-center gap-1.5 [&>svg]:h-3 [&>svg]:w-3 [&>svg]:text-muted-foreground"

  # recharts DefaultZIndexes (es6/zIndex/DefaultZIndexes.js): every layer exists in the SVG, empty or not.
  Z_LAYERS = [ -100, -50, 100, 200, 300, 400, 500, 600, 1000, 1100, 1200, 2000 ].freeze

  Margin = Struct.new(:top, :right, :bottom, :left)
  Box = Struct.new(:x, :y, :width, :height)
  # `color` is the ChartConfig color (the --color-<key> variable); `fill` what the graphical item paints with.
  Series = Struct.new(:key, :label, :color) do
    def fill = "var(--color-#{key})"
  end

  # A rendered axis: `box` is the axis rectangle, ticks carry the label, the pixel coordinate and the label coordinate.
  Axis = Struct.new(:name, :orientation, :box, :tick_margin, :ticks, keyword_init: true)
  Tick = Struct.new(:label, :coordinate, :tick_coord, :shown)

  # Text metrics the oracle page pins (12px / 16px monospace): the browser measures, the server must assume.
  TEXT_HEIGHT = 16.0
  TEXT_CHAR_WIDTH = 7.2

  # recharts cartesian/getTicks.js getTicksEnd (the default interval="preserveEnd"): tickCoord keeps the last label inside the viewBox
  # (0, 0, width, height of the chart) and hides labels that would overlap. Sizes come from `size_of`: the browser measures, the spike assumes.
  module TickLayout
    MIN_TICK_GAP = 5

    module_function

    def apply(ticks, sign:, start:, finish:, size_of:)
      result = ticks.map { |t| Tick.new(t.label, t.coordinate, nil, false) }
      (result.size - 1).downto(0) do |i|
        entry = result[i]
        size = size_of.call(entry)
        entry.tick_coord = i == result.size - 1 ? clamp_last(entry, size, sign, finish) : entry.coordinate
        next unless visible?(sign, entry.tick_coord, size, start, finish)

        finish = entry.tick_coord - (sign * ((size / 2) + MIN_TICK_GAP))
        entry.shown = true
      end
      result.select(&:shown)
    end

    def clamp_last(entry, size, sign, finish)
      gap = sign * (entry.coordinate + (sign * size / 2) - finish)
      gap.positive? ? entry.coordinate - (gap * sign) : entry.coordinate
    end

    def visible?(sign, position, size, start, finish)
      return false if (sign * position) < (sign * start) || (sign * position) > (sign * finish)

      (sign * (position - (sign * size / 2) - start)) >= 0 && (sign * (position + (sign * size / 2) - finish)) <= 0
    end
  end

  # The SVG half. Subclasses fill the layers; the shell (title, desc, z layers, clip path) is recharts' own.
  class Surface < Phlex::SVG
    def initialize(width:, height:, plot:, axes:, clip_id:)
      @width = width
      @height = height
      @plot = plot
      @axes = axes
      @clip_id = clip_id
    end

    def view_template
      svg(role: "application", tabindex: "0", class: "recharts-surface", width: @width, height: @height,
          viewBox: "0 0 #{@width} #{@height}", style: "width: 100%; height: 100%; display: block;") do
        title
        desc
        Z_LAYERS.each do |z|
          layer(z) { send(:"layer_#{z.to_s.tr('-', 'm')}") }
          clip_defs if z == -50
        end
      end
    end

    private

    def layer(z, &) = g(tabindex: "-1", class: "recharts-zIndex-layer_#{z}", &)

    def clip_defs
      defs { clipPath(id: @clip_id) { rect(x: Num.js(@plot.x), y: Num.js(@plot.y), height: Num.js(@plot.height), width: Num.js(@plot.width)) } }
    end

    # Layers a chart does not fill stay empty (recharts always renders them).
    %w[m100 m50 100 200 300 400 600 1000 1100 1200].each { |z| define_method(:"layer_#{z}") { nil } }

    def grid(coordinates)
      g(class: "recharts-cartesian-grid") do
        g(class: "recharts-cartesian-grid-horizontal") do
          coordinates.each do |y|
            line(stroke: "#ccc", fill: "none", x: Num.js(@plot.x), y: Num.js(@plot.y), width: Num.js(@plot.width), height: Num.js(@plot.height),
                 x1: Num.js(@plot.x), y1: Num.js(y), x2: Num.js(@plot.x + @plot.width), y2: Num.js(y))
          end
        end
      end
    end

    # layer 500: the tick containers (tickLine={false}: each tick is an empty <g>)
    def layer_500
      @axes.each do |axis|
        g(class: "recharts-layer recharts-cartesian-axis recharts-#{axis.name} #{axis.name}") do
          g(class: "recharts-cartesian-axis-ticks recharts-#{axis.name}-ticks") do
            g(class: "recharts-cartesian-axis-tick-lines recharts-#{axis.name}-tick-lines") do
              axis.ticks.each { g(class: "recharts-layer recharts-cartesian-axis-tick") }
            end
          end
        end
      end
    end

    # layer 2000: the tick labels
    def layer_2000
      @axes.each do |axis|
        g(class: "recharts-cartesian-axis-tick-labels recharts-#{axis.name}-tick-labels") do
          axis.ticks.each { |tick| tick_label(axis, tick) }
        end
      end
    end

    def tick_label(axis, tick)
      horizontal = %i[top bottom].include?(axis.orientation)
      x, y = label_position(axis, tick)
      g(class: "recharts-layer recharts-cartesian-axis-tick-label") do
        text(orientation: axis.orientation, width: Num.js(axis.box.width), height: Num.js(axis.box.height), stroke: "none", x: Num.js(x), y: Num.js(y),
             class: "recharts-text recharts-cartesian-axis-tick-value", "text-anchor": horizontal ? "middle" : "end", fill: "#666") do
          tspan(x: Num.js(x), dy: horizontal ? "0.71em" : "0.355em") { tick.label }
        end
      end
    end

    # CartesianAxis getTickLineCoord: tickSize 6 + tickMargin from the axis edge (bottom axis, left axis).
    def label_position(axis, tick)
      tick_size = 6
      if axis.orientation == :bottom
        [tick.tick_coord, axis.box.y + tick_size + axis.tick_margin]
      else
        [axis.box.x + axis.box.width - tick_size - axis.tick_margin, tick.tick_coord]
      end
    end
  end

  # The HTML half: shadcn container, the recharts wrappers, tooltip and legend content.
  class Frame < Phlex::HTML
    def initialize(id:, series:, width: 320, height: 200)
      @id = id
      @series = series
      @width = width
      @height = height
    end

    def view_template
      div(data_slot: "chart", data_chart: "chart-#{@id}", class: CHART_CLASS) do
        style { raw safe(chart_style) }
        div(class: "recharts-responsive-container", style: "width: 100%; height: 100%; min-width: 0px;") do
          div(style: "width: 0px; height: 0px; overflow: visible;") do
            div(width: @width, height: @height, class: "recharts-wrapper",
                style: "position: relative; cursor: default; width: #{@width}px; height: #{@height}px;") do
              tooltip_wrapper
              legend_wrapper
              render surface
            end
          end
        end
      end
    end

    private

    # chart.tsx ChartStyle: one rule per theme.
    def chart_style
      vars = @series.map { |s| "  --color-#{s.key}: #{s.color};" }.join("\n")
      [ "", ".dark" ].map { |prefix| "\n#{prefix} [data-chart=chart-#{@id}] {\n#{vars}\n}\n" }.join("\n")
    end

    def legend_wrapper = nil

    def tooltip_item(series, value)
      div(class: TOOLTIP_ITEM_CLASS) do
        div(class: TOOLTIP_INDICATOR_CLASS, style: "--color-bg: #{series.fill}; --color-border: #{series.fill};")
        div(class: "flex flex-1 justify-between leading-none items-center") do
          div(class: "grid gap-1.5") { span(class: "text-muted-foreground") { series.label } }
          span(class: "font-mono font-medium text-foreground tabular-nums") { value.to_s.reverse.scan(/\d{1,3}/).join(",").reverse }
        end
      end
    end
  end
end

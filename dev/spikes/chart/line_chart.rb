# frozen_string_literal: true

require_relative "frame"

module ChartSpike
  # Monotone line chart (LineChart accessibilityLayer margin {left: 12, right: 12} + CartesianGrid vertical=false + XAxis + YAxis +
  # Tooltip cursor=false + Line type=monotone dot) for a 320x200 initialDimension. Sources (node_modules/recharts/es6): cartesian/Line.js
  # (:205 dots, :265 curve, :516 layer), shape/Curve.js getPath (:71), shape/Dot.js, cartesian/CartesianAxis.js getTickLineCoord (:125).
  class LineChart < Frame
    MARGIN = Margin.new(0, 12, 0, 12)
    X_AXIS_HEIGHT = 30
    Y_AXIS_WIDTH = 60 # YAxis default width

    attr_reader :plot, :band, :y_scale, :y_ticks, :points

    def initialize(data:, series:, category_key:, **)
      super(series:, **)
      @data = data
      @category_key = category_key
      @plot = Box.new(MARGIN.left + Y_AXIS_WIDTH, MARGIN.top, @width - MARGIN.left - Y_AXIS_WIDTH - MARGIN.right,
                      @height - MARGIN.top - MARGIN.bottom - X_AXIS_HEIGHT)
      key = @series.first.key
      @y_ticks = NiceTicks.values(0, @data.map { |row| row.fetch(key) }.max)
      @y_scale = Linear.new([ @y_ticks.first, @y_ticks.last ], [ @plot.y + @plot.height, @plot.y ])
      @band = Band.new(@data.size, [ @plot.x, @plot.x + @plot.width ], point: true)
      @points = @data.each_with_index.map { |row, i| [ @band.tick(i), @y_scale.map(row.fetch(key)) ] }
    end

    private

    def surface
      x_axis = Axis.new(name: "xAxis", orientation: :bottom, box: Box.new(@plot.x, @plot.y + @plot.height, @plot.width, X_AXIS_HEIGHT), tick_margin: 8,
                        ticks: TickLayout.apply(category_ticks, sign: 1, start: 0, finish: @width, size_of: ->(t) { t.label.length * TEXT_CHAR_WIDTH }))
      y_axis = Axis.new(name: "yAxis", orientation: :left, box: Box.new(MARGIN.left, @plot.y, Y_AXIS_WIDTH, @plot.height), tick_margin: 8,
                        ticks: TickLayout.apply(value_ticks, sign: -1, start: @height, finish: 0, size_of: ->(_) { TEXT_HEIGHT }))
      LineSurface.new(width: @width, height: @height, plot: @plot, axes: [ x_axis, y_axis ], clip_id: "recharts1-clip", chart: self)
    end

    def category_ticks
      @data.each_with_index.map { |row, i| Tick.new(row.fetch(@category_key)[0, 3], @band.tick(i), nil, false) }
    end

    def value_ticks = @y_ticks.map { |v| Tick.new(Num.js(v), @y_scale.map(v), nil, false) }

    # Tooltip without defaultIndex: an empty, hidden wrapper.
    def tooltip_wrapper
      div(xmlns: "http://www.w3.org/1999/xhtml", tabindex: "-1", class: "recharts-tooltip-wrapper",
          style: "visibility: hidden; pointer-events: none; position: absolute; top: 0px; left: 0px;")
    end
  end

  class LineSurface < Surface
    def initialize(chart:, **rest)
      super(**rest)
      @chart = chart
    end

    private

    def layer_m100 = grid(@chart.y_ticks.map { |v| @chart.y_scale.map(v) })

    def layer_400
      g(class: "recharts-layer recharts-line") do
        g(class: "recharts-layer recharts-shape") do
          path(stroke: "var(--color-desktop)", "stroke-width": "2", fill: "none", id: "recharts-line-1", height: Num.js(@plot.height),
               width: Num.js(@plot.width), class: "recharts-curve recharts-line-curve", d: MonotoneX.path(@chart.points))
        end
      end
    end

    def layer_600
      g(class: "recharts-layer recharts-line-dots") do
        @chart.points.each do |x, y|
          circle(r: "3", stroke: "var(--color-desktop)", "stroke-width": "2", fill: "#fff", height: Num.js(@plot.height), width: Num.js(@plot.width),
                 cx: Num.js(x), cy: Num.js(y), class: "recharts-dot recharts-line-dot")
        end
      end
    end
  end
end

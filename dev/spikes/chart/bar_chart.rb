# frozen_string_literal: true

require_relative "frame"

module ChartSpike
  # Stacked bar chart (BarChart accessibilityLayer + CartesianGrid vertical=false + XAxis + Tooltip defaultIndex + Legend + 2 stacked Bars),
  # laid out like recharts 3.8 for a 320x200 initialDimension. Layout sources (node_modules/recharts/es6): state/selectors/combiners/
  # combineAllBarPositions.js (bar width/offset), cartesian/Bar.js computeBarRectangles (:556), shape/Rectangle.js getRectanglePath (:31).
  class BarChart < Frame
    MARGIN = Margin.new(5, 5, 5, 5)
    X_AXIS_HEIGHT = 30
    BAR_CATEGORY_GAP = 0.1 # barCategoryGap="10%"
    # The legend box is measured by the browser (useElementOffset); 28 = pt-3 (12) + one 16px line in the oracle page.
    LEGEND_HEIGHT = 28
    RADII = [ [ 0, 0, 4, 4 ], [ 4, 4, 0, 0 ] ].freeze # bottom series rounded at the bottom, top series at the top

    attr_reader :plot, :band, :y_scale, :y_ticks, :default_index

    def initialize(data:, series:, category_key:, default_index: nil, **)
      super(series:, **)
      @data = data
      @category_key = category_key
      @default_index = default_index
      @plot = Box.new(MARGIN.left, MARGIN.top, @width - MARGIN.left - MARGIN.right, @height - MARGIN.top - MARGIN.bottom - X_AXIS_HEIGHT - LEGEND_HEIGHT)
      @stacks = Stack.series(@data, @series.map(&:key))
      @y_ticks = NiceTicks.values(0, @stacks.values.flatten(1).map(&:last).max)
      @y_scale = Linear.new([ @y_ticks.first, @y_ticks.last ], [ @plot.y + @plot.height, @plot.y ])
      @band = Band.new(@data.size, [ @plot.x, @plot.x + @plot.width ])
    end

    # Geometry of every bar rectangle: { series:, x:, y:, width:, height:, radius: }.
    def rectangles
      offset = BAR_CATEGORY_GAP * @band.step
      size = ((@band.step - (2 * offset)) / 1).then { |s| s > 1 ? s.floor : s } # one stack, barGap irrelevant; `>> 0` truncates
      @series.each_with_index.flat_map do |s, si|
        @data.each_index.map do |i|
          y0, y1 = @stacks.fetch(s.key)[i]
          base = @y_scale.map(y0)
          top = @y_scale.map(y1)
          { series: s, index: si, x: @band.tick(i) - (@band.step / 2) + offset, y: top, width: size, height: base - top, radius: RADII[si] }
        end
      end
    end

    private

    def surface
      x_axis = Axis.new(name: "xAxis", orientation: :bottom, box: Box.new(@plot.x, @plot.y + @plot.height, @plot.width, X_AXIS_HEIGHT), tick_margin: 10,
                        ticks: TickLayout.apply(category_ticks, sign: 1, start: 0, finish: @width, size_of: ->(t) { t.label.length * TEXT_CHAR_WIDTH }))
      BarSurface.new(width: @width, height: @height, plot: @plot, axes: [ x_axis ], clip_id: "recharts1-clip", chart: self)
    end

    def category_ticks
      @data.each_with_index.map { |row, i| Tick.new(row.fetch(@category_key)[0, 3], @band.tick(i), nil, false) } # tickFormatter: slice(0, 3)
    end

    def tooltip_wrapper
      div(xmlns: "http://www.w3.org/1999/xhtml", tabindex: "-1", class: "recharts-tooltip-wrapper",
          style: "visibility: #{@default_index ? 'visible' : 'hidden'}; pointer-events: none; position: absolute; top: 0px; left: 0px;") do
        next unless @default_index

        div(class: TOOLTIP_CLASS) do
          div(class: "grid gap-1.5") { @series.each { |s| tooltip_item(s, @data.fetch(@default_index).fetch(s.key)) } }
        end
      end
    end

    def legend_wrapper
      div(class: "recharts-legend-wrapper",
          style: "position: absolute; width: #{Num.js(@width - MARGIN.left - MARGIN.right)}px; height: auto; left: #{MARGIN.left}px; bottom: #{MARGIN.bottom}px;") do
        div(class: LEGEND_CLASS) do
          @series.each do |s|
            div(class: LEGEND_ITEM_CLASS) do
              div(class: "h-2 w-2 shrink-0 rounded-[2px]", style: "background-color: #{s.fill};")
              plain s.label
            end
          end
        end
      end
    end
  end

  class BarSurface < Surface
    def initialize(chart:, **rest)
      super(**rest)
      @chart = chart
    end

    private

    def layer_m100 = grid(@chart.y_ticks.map { |v| @chart.y_scale.map(v) })

    # Tooltip cursor (cursor rectangle of the active category), layer 200.
    def layer_200
      index = @chart.default_index
      return unless index

      x = @chart.band.tick(index) - (@chart.band.step / 2)
      w = @chart.band.step
      h = @plot.height - 1
      y = @plot.y + 0.5
      path(stroke: "none", "pointer-events": "none", width: r4(w), height: r4(h), fill: "#ccc", x: r4(x), y: r4(y),
           class: "recharts-rectangle recharts-tooltip-cursor", radius: "0", d: "M #{r4(x)},#{r4(y)} h #{r4(w)} v #{r4(h)} h #{r4(-w)} Z")
    end

    def layer_300
      @chart.rectangles.group_by { |r| r[:index] }.each do |si, rects|
        g(class: "recharts-layer recharts-bar", id: "recharts-bar-#{si + 1}") do
          g(class: "recharts-layer recharts-bar-rectangles") do
            g(class: "recharts-layer") { rects.each { |r| rectangle(r) } }
          end
        end
      end
    end

    def rectangle(rect)
      g(class: "recharts-layer recharts-bar-rectangle") do
        g(class: "recharts-layer recharts-inactive-bar") do
          path(fill: rect[:series].fill, name: "undefined", x: r4(rect[:x]), y: r4(rect[:y]), width: r4(rect[:width]), height: r4(rect[:height]),
               class: "recharts-rectangle", d: rounded_rect_path(rect[:x], rect[:y], rect[:width], rect[:height], rect[:radius]))
        end
      end
    end

    def r4(value) = Num.js(Num.round(value, 4))

    # shape/Rectangle.js getRectanglePath for an array radius (positive width/height): corners in order top-left, top-right, bottom-right, bottom-left.
    def rounded_rect_path(x, y, w, h, radius)
      max = [ w.abs / 2, h.abs / 2 ].min
      r = radius.map { |v| [ v, max ].min }
      d = +"M#{r4(x)},#{r4(y + r[0])}"
      d << "A #{r4(r[0])},#{r4(r[0])},0,0,1,#{r4(x + r[0])},#{r4(y)}" if r[0].positive?
      d << "L #{r4(x + w - r[1])},#{r4(y)}"
      d << "A #{r4(r[1])},#{r4(r[1])},0,0,1,\n        #{r4(x + w)},#{r4(y + r[1])}" if r[1].positive?
      d << "L #{r4(x + w)},#{r4(y + h - r[2])}"
      d << "A #{r4(r[2])},#{r4(r[2])},0,0,1,\n        #{r4(x + w - r[2])},#{r4(y + h)}" if r[2].positive?
      d << "L #{r4(x + r[3])},#{r4(y + h)}"
      d << "A #{r4(r[3])},#{r4(r[3])},0,0,1,\n        #{r4(x)},#{r4(y + h - r[3])}" if r[3].positive?
      d << "Z"
    end
  end
end

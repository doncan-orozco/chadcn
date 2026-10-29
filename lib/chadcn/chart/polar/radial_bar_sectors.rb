# frozen_string_literal: true

# The arcs of one radial bar: recharts' `computeRadialBarDataItems` (polar/RadialBar.js:332-405) for the `radial` layout (the radius axis
# holds the categories). An arc starts at the angle of the bottom of its value and ends at that of its top (a stacked arc rides on the
# ones below it, kept inside the domain of the angle axis), and takes its place in the ring of its category from the bar positions.
#
# @api private
module Chadcn::Chart::Polar::RadialBarSectors
  # One arc. `value` is the number it shows (the `[lower, upper]` pair when stacked), `background` the arc behind it spanning the whole angle
  # (nil when it is not drawn), `attributes` the SVG attributes the row and its cell give the path (the cell wins). A nil radius or angle is an
  # arc that cannot be drawn.
  Sector = Data.define(:index, :row, :value, :cx, :cy, :inner_radius, :outer_radius, :start_angle, :end_angle, :background, :attributes) do
    # The angles, as the view box of a label.
    #
    # @api private
    # @return [Chadcn::Chart::Polar::ViewBox]
    def view_box
      Chadcn::Chart::Polar::ViewBox.new(cx: cx, cy: cy, inner_radius: inner_radius, outer_radius: outer_radius, start_angle: start_angle, end_angle: end_angle)
    end

    # @api private
    # @return [Boolean] whether the arc has a place to be drawn
    def drawable? = [ inner_radius, outer_radius, start_angle, end_angle ].none?(&:nil?)
  end

  # The row keys recharts lets through to an arc (`svgPropertiesNoEvents` of the entry); the same four a bar takes.
  ROW_ATTRIBUTES = %i[fill stroke name opacity].freeze

  private_constant :ROW_ATTRIBUTES

  class << self
    # @api private
    # @param series [Chadcn::Chart::RadialBar]
    # @param rows [Array<Hash>] the data of the chart
    # @param axes [Hash] `angle:` and `radius:`, the {Chadcn::Chart::Polar::Axis}es the arcs are measured on and placed on
    # @param view_box [Chadcn::Chart::Polar::ViewBox]
    # @param position [Chadcn::Chart::Cartesian::BarPositions::Position] where the series sits inside its ring (`offset` and `size`)
    # @param pairs [Array<Array(Float, Float)>, nil] the stacked `[lower, upper]` of every row, nil when the series is not stacked
    # @return [Array<Sector>] one per row
    def call(series, rows:, axes:, view_box:, position:, pairs:)
      angle = axes[:angle]
      base = base_value(angle)
      band = axes[:radius].band_size
      rows.each_with_index.map do |row, index|
        value = value_of(series, row, pairs&.[](index), angle, base)
        sector(series, row, index, value, { view_box: view_box, angle: angle, radius: axes[:radius], position: position, band: band })
      end
    end

    private

    # The `[lower, upper]` of a row: its stacked pair kept inside the angle domain, else from the base to its value (an array is its own range).
    def value_of(series, row, pair, angle, base)
      return truncate(pair, angle.domain) if pair

      value = Chadcn::Chart::Cartesian::Value.read(row, series.options[:data_key])
      value.is_a?(Array) ? value : [ base, value ]
    end

    # `getBaseValueOfBar`: zero when the domain holds it, else the end of the domain nearest to it.
    def base_value(angle)
      domain = angle.domain
      return 0.0 unless angle.settings.type == :number && domain.is_a?(Array) && domain.size == 2

      low, high = domain.minmax
      return 0.0 if 0.between?(low, high)

      high.negative? ? high : low
    end

    # `truncateByDomain` (util/ChartUtils.js:185-205).
    def truncate(pair, domain)
      return pair unless domain.is_a?(Array) && domain.size == 2 && domain.all? { |bound| Chadcn::Chart::Cartesian::Value.numeric?(bound) }

      low, high = domain.minmax
      lower = Chadcn::Chart::Cartesian::Value.numeric?(pair[0]) && pair[0] >= low ? pair[0] : low
      upper = Chadcn::Chart::Cartesian::Value.numeric?(pair[1]) && pair[1] <= high ? pair[1] : high
      [ [ lower, high ].min, [ upper, low ].max ]
    end

    def sector(series, row, index, value, context)
      box = context[:view_box]
      start = context[:angle].position_of(value[0])
      stop = context[:angle].position_of(value[1])
      inner = inner_radius(context, row, index)
      outer = inner + context[:position].size if inner
      stop = widen(stop, start, series.options[:min_point_size]) if start && stop
      complete = inner && outer && start && stop
      Sector.new(index: index, row: row, value: stacked_value(series, value), cx: box.cx, cy: box.cy, inner_radius: inner, outer_radius: outer,
                 start_angle: start, end_angle: stop, background: (background(box, inner, outer) if complete), attributes: attributes(series, row, index))
    end

    # `value: stackedData ? value : value[1]`
    def stacked_value(series, value) = series.options[:stack_id].nil? ? value[1] : value

    # `getCateCoordinateOfBar` (util/ChartUtils.js:381-403): the start of the ring of the category plus where the bar sits in it.
    def inner_radius(context, row, index)
      axis = context[:radius]
      if axis.category?
        tick = axis.item_ticks[index]
        return tick && (tick.coordinate + context[:position].offset)
      end

      scaled = axis.position_of(Chadcn::Chart::Cartesian::Value.read(row, axis.settings.data_key))
      scaled && (scaled - (context[:band] / 2.0) + context[:position].offset)
    end

    # An arc that turns less than `min_point_size` is lengthened to it (polar/RadialBar.js:358-362).
    def widen(stop, start, min_point_size)
      delta = stop - start
      return stop unless min_point_size.abs.positive? && delta.abs < min_point_size.abs

      stop + (Chadcn::Chart::Shape::JsMath.sign(delta.zero? ? min_point_size : delta) * (min_point_size.abs - delta.abs))
    end

    def background(box, inner, outer)
      { cx: box.cx, cy: box.cy, inner_radius: inner, outer_radius: outer, start_angle: box.start_angle.to_f, end_angle: box.end_angle.to_f }
    end

    # What a row and its cell give the path: the row's `fill`, `stroke`, `name` and `opacity`, then everything the cell has.
    def attributes(series, row, index)
      from_row = row.is_a?(Hash) ? ROW_ATTRIBUTES.to_h { |key| [ key, Chadcn::Chart::Cartesian::Value.read(row, key) ] }.compact : {}
      from_row.merge(series.cells[index]&.shape_attributes || {})
    end
  end
end

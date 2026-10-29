# frozen_string_literal: true

# The sectors of one pie: recharts' `computePieSectors` (polar/Pie.js:340-419) over the rows the pie shows. The angles are the pie angle
# layout ({Chadcn::Chart::Shape::Pie}); the center and the radii come from the plot rectangle the pie sits in (`parseCoordinateOfPie`,
# polar/Pie.js:155-175). A pie whose values total nothing has no sectors.
#
# @api private
module Chadcn::Chart::Polar::PieSectors
  # One sector. `name` is the row's `name_key` value (the row index when it has none), `attributes` the SVG attributes the row and its
  # cell give the path (the cell wins), `tooltip_position` the point a tooltip anchors to.
  Sector = Data.define(:index, :row, :name, :value, :percent, :cx, :cy, :inner_radius, :outer_radius, :start_angle, :end_angle,
                       :mid_angle, :middle_radius, :padding_angle, :corner_radius, :attributes, :tooltip_position) do
    # The angles, as the view box of a label.
    #
    # @api private
    # @return [Chadcn::Chart::Polar::ViewBox]
    def view_box
      Chadcn::Chart::Polar::ViewBox.new(cx: cx, cy: cy, inner_radius: inner_radius, outer_radius: outer_radius, start_angle: start_angle,
                                        end_angle: end_angle)
    end
  end

  # The row keys recharts lets through to a sector (`svgPropertiesNoEvents` of the entry) that a data row may carry; the same four a bar takes.
  ROW_ATTRIBUTES = %i[fill stroke name opacity].freeze

  private_constant :ROW_ATTRIBUTES

  class << self
    # @api private
    # @param series [Chadcn::Chart::Pie] the declared pie
    # @param rows [Array<Hash>] the rows the pie shows (its own `data:`, else the chart's)
    # @param plot [Hash{Symbol => Float}] `x`, `y`, `width` and `height` of the plot rectangle
    # @return [Array<Sector>] one per row, [] when the values total nothing
    def call(series, rows:, plot:)
      options = series.options
      values = rows.map { |row| Chadcn::Chart::Cartesian::Value.read(row, options[:data_key]) }
      angles = Chadcn::Chart::Shape::Pie.layout(values, start_angle: options[:start_angle], end_angle: options[:end_angle],
                                                        pad_angle: options[:padding_angle], min_angle: options[:min_angle])
      return [] if angles.empty?

      center = center(options, plot)
      direction = Chadcn::Chart::Shape::JsMath.sign(Chadcn::Chart::Shape::Polar.delta_angle(options[:start_angle], options[:end_angle], limit: 360))
      rows.each_with_index.map do |row, index|
        sector(series, row, index, angles[index], center.merge(padding_angle: direction * options[:padding_angle], value: values[index] || 0))
      end
    end

    # The SVG attributes a sector gives what is drawn for it (its path, its label and its label line): the pie's own presentation props
    # (`svgPropertiesNoEvents(props)`, polar/Pie.js:623), then the name, the row's and the cell's attributes, then the center
    # (polar/Pie.js:399-414: later spreads win; a `class:` replaces the earlier one). The pie's `id` is not among them.
    #
    # @api private
    # @param series [Chadcn::Chart::Pie]
    # @param sector [Sector]
    # @return [Hash{Symbol => Object}]
    def presentation(series, sector)
      options = series.options
      own = { fill: options[:fill], stroke: options[:stroke], stroke_width: options[:stroke_width] }.merge(options[:attrs].except(:id))
      own.merge(name: sector.name.to_s).merge(sector.attributes).merge(cx: sector.cx, cy: sector.cy).compact
    end

    private

    # `parseCoordinateOfPie`: the center and the two radii, in pixels.
    def center(options, plot)
      value = Chadcn::Chart::Cartesian::Value
      max = [ plot[:width].abs, plot[:height].abs ].min / 2.0
      { cx: plot[:x] + value.percent(options[:cx], plot[:width], plot[:width] / 2.0),
        cy: plot[:y] + value.percent(options[:cy], plot[:height], plot[:height] / 2.0),
        inner_radius: value.percent(options[:inner_radius], max, 0.0), outer_radius: value.percent(options[:outer_radius], max, max * 0.8) }
    end

    def sector(series, row, index, angle, geometry)
      options = series.options
      middle = (geometry[:inner_radius] + geometry[:outer_radius]) / 2.0
      cell = series.cells[index]
      Sector.new(
        index: index, row: row, name: name(row, options[:name_key], index), value: geometry[:value], percent: angle[:percent], cx: geometry[:cx],
        cy: geometry[:cy], inner_radius: geometry[:inner_radius], outer_radius: geometry[:outer_radius], start_angle: angle[:start_angle],
        end_angle: angle[:end_angle], mid_angle: angle[:mid_angle], middle_radius: middle, padding_angle: geometry[:padding_angle],
        corner_radius: corner_radius(options[:corner_radius]), attributes: attributes(row, cell),
        tooltip_position: Chadcn::Chart::Shape::Polar.polar_to_cartesian(geometry[:cx], geometry[:cy], middle, angle[:mid_angle])
      )
    end

    # `getValueByDataKey(entry, nameKey, i)`: the row index stands for a row without a name.
    def name(row, name_key, index)
      found = Chadcn::Chart::Cartesian::Value.read(row, name_key)
      found.nil? ? index : found
    end

    # What a row and its cell give the path: the row's `fill`, `stroke`, `name` and `opacity`, then everything the cell has.
    def attributes(row, cell)
      from_row = row.is_a?(Hash) ? ROW_ATTRIBUTES.to_h { |key| [ key, Chadcn::Chart::Cartesian::Value.read(row, key) ] }.compact : {}
      from_row.merge(cell&.shape_attributes || {})
    end

    # `typeof cornerRadius === 'string' ? parseFloat(cornerRadius) : cornerRadius` (polar/Pie.js:401): a text keeps its leading number.
    def corner_radius(value)
      return value unless value.is_a?(String)

      match = value.strip.match(/\A[+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?/i)
      match ? match[0].to_f : Float::NAN
    end
  end
end

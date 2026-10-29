# frozen_string_literal: true

# recharts' `PolarGrid` (polar/PolarGrid.js): the web behind a radar or radial bar chart, a concentric ring for every tick of the radius
# axis and (with `radial_lines`) a line from the center for every tick of the angle axis. It renders nothing where it is written; the chart
# draws it in the lowest layer.
#
# `class:` and every other attribute land on every ring and every line, as in recharts (the group takes none).
#
# @example
#   chart.polar_grid(grid_type: :circle, radial_lines: false)
class Chadcn::Chart::PolarGrid < Chadcn::Chart::Declaration
  include Chadcn::Chart::Cartesian::Choice

  # Values of `grid_type:`.
  GRID_TYPES = %i[polygon circle].freeze

  # @api private
  # @return [Hash{Symbol => Object}] the keywords with recharts' defaults applied, frozen
  attr_reader :options

  # @param grid_type [Symbol] `:polygon` (a ring is a polygon through the angle ticks) or `:circle`
  # @param polar_angles [Array<Numeric>, nil] the angle of every radial line, degrees, instead of the ticks of the angle axis
  # @param polar_radius [Array<Numeric>, nil] the radius of every ring, px, instead of the ticks of the radius axis
  # @param stroke [String] color of the rings and the lines
  # @param fill [String, nil] draws a background shape behind the rings (the outermost ring, filled) unless nil or `"none"`
  # @param radial_lines [Boolean] draw the lines from the center
  # @param angle_axis_id [Object] the angle axis the lines follow
  # @param radius_axis_id [Object] the radius axis the rings follow
  # @param attrs [Hash] attributes of every ring and line
  # @raise [ArgumentError] on a `grid_type:` that is neither `:polygon` nor `:circle`, or a `polar_angles:` / `polar_radius:` that is not a list of numbers
  def initialize(grid_type: :polygon, polar_angles: nil, polar_radius: nil, stroke: "#ccc", fill: nil, radial_lines: true, angle_axis_id: 0,
                 radius_axis_id: 0, **attrs)
    { polar_angles: polar_angles, polar_radius: polar_radius }.each do |name, list|
      next if list.nil? || (list.is_a?(Array) && list.all?(Numeric))

      raise ArgumentError, "#{name}: must be an Array of numbers (got #{list.inspect})"
    end
    @options = { grid_type: choice(:grid_type, grid_type, GRID_TYPES), polar_angles: polar_angles, polar_radius: polar_radius, stroke: stroke, fill: fill,
                 radial_lines: radial_lines, angle_axis_id: angle_axis_id, radius_axis_id: radius_axis_id, attrs: attrs }.freeze
    super()
  end
end

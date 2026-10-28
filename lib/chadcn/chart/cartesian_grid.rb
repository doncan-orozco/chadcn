# frozen_string_literal: true

# recharts' `CartesianGrid` (cartesian/CartesianGrid.js): the lines behind the plot, one for every tick of the axes (and the edges of the
# plot). It renders nothing where it is written; the chart draws it in the lowest layer.
#
# `class:` and every other attribute land on every grid line, as in recharts (the group takes none).
#
# @example
#   chart.cartesian_grid(vertical: false)
class Chadcn::Chart::CartesianGrid < Chadcn::Chart::Declaration
  # @api private
  # @return [Hash{Symbol => Object}] the keywords with recharts' defaults applied, frozen
  attr_reader :options

  # @param horizontal [Boolean] draw the horizontal lines
  # @param vertical [Boolean] draw the vertical lines
  # @param stroke [String] color of the lines
  # @param fill [String] fill of the plot behind the lines (`"none"`: none)
  # @param stroke_dasharray [String, nil]
  # @param horizontal_points [Array<Numeric>] the y of every horizontal line, instead of the ticks
  # @param vertical_points [Array<Numeric>] the x of every vertical line, instead of the ticks
  # @param horizontal_fill [Array<String>] colors for the bands between horizontal lines, in turn
  # @param vertical_fill [Array<String>] colors for the bands between vertical lines, in turn
  # @param sync_with_ticks [Boolean] only a line for every tick, not the edges of the plot
  # @param x_axis_id [Object] the x axis the vertical lines follow
  # @param y_axis_id [Object] the y axis the horizontal lines follow
  # @param attrs [Hash] attributes of every line
  def initialize(horizontal: true, vertical: true, stroke: "#ccc", fill: "none", stroke_dasharray: nil, horizontal_points: [], vertical_points: [], horizontal_fill: [],
                 vertical_fill: [], sync_with_ticks: false, x_axis_id: 0, y_axis_id: 0, **attrs)
    @options = { horizontal: horizontal, vertical: vertical, stroke: stroke, fill: fill, stroke_dasharray: stroke_dasharray, horizontal_points: horizontal_points,
                 vertical_points: vertical_points, horizontal_fill: horizontal_fill, vertical_fill: vertical_fill, sync_with_ticks: sync_with_ticks,
                 x_axis_id: x_axis_id, y_axis_id: y_axis_id, attrs: attrs }.freeze
    super()
  end
end

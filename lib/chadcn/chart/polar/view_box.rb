# frozen_string_literal: true

# The polar view box of a chart (state/selectors/polarAxisSelectors.js `selectPolarViewBox`): the center, the two radii the plot spans and
# the angles it runs between, all resolved to pixels and degrees. Angles are degrees, counterclockwise from 3 o'clock, as in recharts.
#
# @api private
Chadcn::Chart::Polar::ViewBox = Data.define(:cx, :cy, :inner_radius, :outer_radius, :start_angle, :end_angle) do
  # The point at `radius` from the center at `angle` (util/PolarUtils.js `polarToCartesian`).
  #
  # @api private
  # @param radius [Numeric]
  # @param angle [Numeric] degrees
  # @return [Array(Float, Float)] x and y
  def point(radius, angle) = Chadcn::Chart::Shape::Polar.polar_to_cartesian(cx, cy, radius, angle)
end

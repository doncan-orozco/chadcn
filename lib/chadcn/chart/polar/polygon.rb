# frozen_string_literal: true

# recharts' `Polygon` path (shape/Polygon.js:12-50): `M x,yL x,y ... Z`, every number rounded to four decimals
# (util/round.js `roundTemplateLiteral`), a point that is not a pair of numbers breaking the polygon.
#
# @api private
module Chadcn::Chart::Polar::Polygon
  class << self
    # `getSinglePolygonPath` without `connectNulls`.
    #
    # @api private
    # @param points [Array<Array(Numeric, Numeric)>] the corners `[x, y]`, in order
    # @return [String, nil] nil without a corner
    def path(points)
      segments = [ [] ]
      points.each do |point|
        if drawable?(point) then segments.last << point
        elsif segments.last.any? then segments << []
        end
      end
      segments.last << points.first if drawable?(points.first)
      segments.pop if segments.last.empty?
      return if segments.empty?

      text = segments.map { |segment| segment.each_with_index.map { |(x, y), index| "#{index.zero? ? 'M' : 'L'}#{number(x)},#{number(y)}" }.join }.join
      segments.one? ? "#{text}Z" : text
    end

    private

    def drawable?(point) = point.is_a?(Array) && point.size == 2 && point.all? { |value| value.is_a?(Numeric) && value.finite? }

    def number(value) = Chadcn::Chart::Shape::Number.format(Chadcn::Chart::Cartesian::Rectangle.round(value))
  end
end

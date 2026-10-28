# frozen_string_literal: true

# The Bezier control points of a natural cubic spline for one coordinate: a tridiagonal system solved with the Thomas algorithm
# (https://www.particleincell.com/2012/bezier-splines/, as in d3-shape curve/natural.js).
#
# @api private
module Chadcn::Chart::Shape::Curve::Natural::ControlPoints
  class << self
    # @api private
    # @param coords [Array<Float>] the coordinate of every point, at least three
    # @return [Array(Array<Float>, Array<Float>)] the first and the second control point coordinate of each of the `coords.size - 1` segments
    def of(coords)
      segments = coords.size - 1
      below = Array.new(segments, 1.0)
      diagonal = Array.new(segments, 4.0)
      below[0] = 0.0
      below[segments - 1] = 2.0
      diagonal[0] = 2.0
      diagonal[segments - 1] = 7.0
      rhs = right_hand_side(coords)
      eliminate(below, diagonal, rhs)
      first = back_substitute(diagonal, rhs)
      [ first, second_points(coords, first) ]
    end

    private

    def right_hand_side(coords)
      last = coords.size - 2
      Array.new(coords.size - 1) do |index|
        if index.zero? then coords[0] + (2 * coords[1])
        elsif index == last then (8 * coords[last]) + coords[last + 1]
        else (4 * coords[index]) + (2 * coords[index + 1])
        end
      end
    end

    # Forward elimination of the sub-diagonal, in place.
    def eliminate(below, diagonal, rhs)
      (1...below.size).each do |row|
        ratio = below[row] / diagonal[row - 1]
        diagonal[row] -= ratio
        rhs[row] -= ratio * rhs[row - 1]
      end
    end

    # The first control points; the super-diagonal is all ones.
    def back_substitute(diagonal, rhs)
      last = diagonal.size - 1
      first = Array.new(diagonal.size)
      first[last] = rhs[last] / diagonal[last]
      (last - 1).downto(0) { |row| first[row] = (rhs[row] - first[row + 1]) / diagonal[row] }
      first
    end

    def second_points(coords, first)
      last = first.size - 1
      Array.new(first.size) { |index| index == last ? (coords[last + 1] + first[last]) / 2 : (2 * coords[index + 1]) - first[index + 1] }
    end
  end
end

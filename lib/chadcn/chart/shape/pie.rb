# frozen_string_literal: true

# The angle layout of recharts' polar/Pie.js `computePieSectors`: consecutive sectors sized by value, each at least `min_angle` wide,
# separated by `pad_angle`. Angles are degrees, counterclockwise from 3 o'clock.
#
# @api private
module Chadcn::Chart::Shape::Pie
  # A pie never turns more than this (Pie.js `parseDeltaAngle`).
  FULL_TURN = 360

  private_constant :FULL_TURN

  class << self
    # Non-numeric values count as 0; with no positive total there is nothing to lay out.
    #
    # @api private
    # @param values [Array<Numeric, nil>]
    # @param start_angle [Numeric] degrees
    # @param end_angle [Numeric] degrees; below `start_angle` the pie runs clockwise
    # @param pad_angle [Numeric] gap between sectors (ignored for a single value)
    # @param min_angle [Numeric] minimum width of every non-zero sector
    # @return [Array<Hash>] one `{ start_angle:, end_angle:, mid_angle:, percent: }` per value, [] when the total is not positive
    def layout(values, start_angle: 0, end_angle: 360, pad_angle: 0, min_angle: 0)
      counted = values.map { |value| value_or_zero(value) }
      total = counted.sum
      return [] unless total.positive?

      turn = Chadcn::Chart::Shape::Polar.delta_angle(start_angle, end_angle, limit: FULL_TURN)
      direction = Chadcn::Chart::Shape::JsMath.sign(turn)
      gap = counted.size <= 1 ? 0 : pad_angle
      minimum = min_angle.abs
      shared = turn.abs - (counted.count { |value| value != 0 } * minimum) - total_gap(counted, turn, gap)
      cursor = start_angle
      counted.each_with_index.map do |value, index|
        present = value.zero? ? 0 : 1
        sector_start = index.zero? ? start_angle : cursor + (direction * gap * present)
        percent = value.to_f / total
        cursor = sector_start + (direction * ((present * minimum) + (percent * shared)))
        { start_angle: sector_start, end_angle: cursor, mid_angle: (sector_start + cursor) / 2, percent: percent }
      end
    end

    private

    # The gaps between the non-zero sectors; a full turn has one more, between the last and the first.
    def total_gap(counted, turn, gap)
      non_zero = counted.count { |value| value != 0 }
      (turn.abs >= FULL_TURN ? non_zero : non_zero - 1) * gap
    end

    # recharts counts what `isNumber` rejects (not a number, NaN) as 0.
    def value_or_zero(value)
      return 0 unless value.is_a?(Numeric)

      value.respond_to?(:nan?) && value.nan? ? 0 : value
    end
  end
end

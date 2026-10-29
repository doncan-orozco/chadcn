# frozen_string_literal: true

# Where a label sits around a polar view box: recharts' `getAttrsOfPolarLabel` (component/Label.js:158-206) for the labels placed by a
# point (`outside`, `center`, `center_top`, `center_bottom`, and any other name at the middle of the ring), and `renderRadialLabel`
# (component/Label.js:92-134) for the ones that follow the arc (`inside_start`, `inside_end`, `end`).
#
# @api private
module Chadcn::Chart::Polar::LabelPosition
  # The anchor point of a label and how the text hangs on it.
  Result = Data.define(:x, :y, :horizontal_anchor, :vertical_anchor)

  # A label that follows the arc: the `path` the text runs along (`M x,y A r,r,0,1,sweep, x,y`).
  Radial = Data.define(:path)

  # The positions whose label runs along the arc.
  RADIAL = %i[inside_start inside_end end].freeze

  class << self
    # @api private
    # @param view_box [Chadcn::Chart::Polar::ViewBox] the sector (or chart) the label belongs to
    # @param position [Symbol, String] a name of {Chadcn::Chart::LabelList::POSITIONS}, or recharts' camelCase spelling
    # @param offset [Numeric] distance from the sector, px (or degrees along the arc)
    # @return [Result, Radial]
    def call(view_box:, position:, offset:)
      name = snake_case(position)
      return radial(view_box, name, offset) if RADIAL.include?(name)

      at_point(view_box, name, offset)
    end

    # @api private
    # @param position [Object]
    # @return [Boolean] whether the label follows the arc
    def radial?(position) = RADIAL.include?(snake_case(position))

    private

    def snake_case(position)
      return unless position.is_a?(Symbol) || position.is_a?(String)

      position.to_s.gsub(/(?<=[a-z])([A-Z])/) { "_#{Regexp.last_match(1).downcase}" }.to_sym
    end

    # `getAttrsOfPolarLabel`
    def at_point(view_box, name, offset)
      middle = (view_box.start_angle + view_box.end_angle) / 2.0
      case name
      when :outside
        x, y = view_box.point(view_box.outer_radius + offset, middle)
        Result.new(x: x, y: y, horizontal_anchor: x >= view_box.cx ? :start : :end, vertical_anchor: :middle)
      when :center then Result.new(x: view_box.cx, y: view_box.cy, horizontal_anchor: :middle, vertical_anchor: :middle)
      when :center_top then Result.new(x: view_box.cx, y: view_box.cy, horizontal_anchor: :middle, vertical_anchor: :start)
      when :center_bottom then Result.new(x: view_box.cx, y: view_box.cy, horizontal_anchor: :middle, vertical_anchor: :end)
      else
        x, y = view_box.point((view_box.inner_radius + view_box.outer_radius) / 2.0, middle)
        Result.new(x: x, y: y, horizontal_anchor: :middle, vertical_anchor: :middle)
      end
    end

    # `renderRadialLabel`: the arc the text follows runs almost a full turn from the label angle, in the direction the sector turns.
    def radial(view_box, name, offset)
      radius = (view_box.inner_radius + view_box.outer_radius) / 2.0
      delta = Chadcn::Chart::Shape::Polar.delta_angle(view_box.start_angle, view_box.end_angle, limit: 360)
      sign = delta >= 0 ? 1 : -1
      angle, clockwise = radial_angle(view_box, name, sign * offset)
      clockwise = !clockwise if delta.positive?
      sx, sy = view_box.point(radius, angle)
      ex, ey = view_box.point(radius, angle + ((clockwise ? 1 : -1) * 359))
      format = Chadcn::Chart::Shape::Number
      Radial.new(path: "M#{format.format(sx)},#{format.format(sy)}\n    A#{format.format(radius)},#{format.format(radius)},0,1,#{clockwise ? 0 : 1},\n    " \
                       "#{format.format(ex)},#{format.format(ey)}")
    end

    # The angle the text starts at and whether it starts as `clockWise` (always false for a polar label list entry).
    def radial_angle(view_box, name, shift)
      case name
      when :inside_start then [ view_box.start_angle + shift, false ]
      when :inside_end then [ view_box.end_angle - shift, true ]
      else [ view_box.end_angle + shift, false ]
      end
    end
  end
end

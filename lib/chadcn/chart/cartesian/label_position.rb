# frozen_string_literal: true

# Where a label sits around a box: recharts' `getCartesianPosition` (cartesian/getCartesianPosition.js) for the rectangular boxes of
# a bar, a data point or the plot, with `clamp: true`.
#
# @api private
module Chadcn::Chart::Cartesian::LabelPosition
  # The position of a label: the text anchor point, how the text hangs on it, and the width / height the label is clamped to (nil
  # when there is no parent box to clamp against).
  Result = Data.define(:x, :y, :horizontal_anchor, :vertical_anchor, :width, :height)

  # The box a label belongs to, its distance from the box and the box it is clamped to, with the offsets and anchors that follow from
  # the direction of the box (a negative `width` or `height` flips them).
  Geometry = Data.define(:x, :y, :width, :height, :offset, :parent) do
    def vertical_offset = (height >= 0 ? 1 : -1) * offset
    def horizontal_offset = (width >= 0 ? 1 : -1) * offset
    def vertical_end = height >= 0 ? :end : :start
    def vertical_start = height >= 0 ? :start : :end
    def horizontal_end = width >= 0 ? :end : :start
    def horizontal_start = width >= 0 ? :start : :end
    def center_x = x + (width / 2)
    def center_y = y + (height / 2)
    def right = x + width
    def bottom = y + height

    # The width and height the label is clamped to: the box's own when there is a parent, none otherwise.
    def clamp_size = parent ? { width: width, height: height } : { width: nil, height: nil }
  end

  OUTSIDE = %i[top bottom left right].freeze
  INSIDE = %i[inside_left inside_right inside_top inside_bottom inside_top_left inside_top_right inside_bottom_left inside_bottom_right].freeze

  private_constant :Geometry, :OUTSIDE, :INSIDE

  class << self
    # @api private
    # @param box [Hash] `x`, `y`, `width`, `height` of the box the label belongs to
    # @param position [Symbol, String, Hash] `:top`, `:bottom`, `:left`, `:right`, `:inside_left` ... (or recharts' `"insideLeft"`) or
    #   `{ x:, y: }`; anything else centers
    # @param offset [Numeric] distance from the box
    # @param parent [Hash, nil] the box the label is clamped to (`x`, `y`, `width`, `height`)
    # @return [Result]
    def call(box:, position:, offset:, parent: nil)
      geometry = Geometry.new(x: box[:x], y: box[:y], width: box[:width], height: box[:height], offset: offset, parent: parent)
      name = snake_case(position)
      named(name, geometry) || free(position, geometry) || centered(geometry)
    end

    private

    # recharts spells positions in camelCase (`"insideLeft"`); they are looked up in snake_case.
    def snake_case(position)
      return unless position.is_a?(Symbol) || position.is_a?(String)

      position.to_s.gsub(/(?<=[a-z])([A-Z])/) { "_#{Regexp.last_match(1).downcase}" }.to_sym
    end

    def named(name, geometry)
      return outside(name, geometry) if OUTSIDE.include?(name)

      inside(name, geometry) if INSIDE.include?(name)
    end

    def outside(name, geometry)
      parent = geometry.parent
      case name
      when :top
        room = parent ? [ geometry.y - parent[:y], 0 ].max : nil
        anchor(left: geometry.center_x, top: geometry.y - geometry.vertical_offset, horizontal: :middle, vertical: geometry.vertical_end,
               width: parent && geometry.width, height: room)
      when :bottom
        room = parent ? [ parent[:y] + parent[:height] - geometry.bottom, 0 ].max : nil
        anchor(left: geometry.center_x, top: geometry.bottom + geometry.vertical_offset, horizontal: :middle, vertical: geometry.vertical_start,
               width: parent && geometry.width, height: room)
      when :left
        edge = geometry.x - geometry.horizontal_offset
        anchor(left: edge, top: geometry.center_y, horizontal: geometry.horizontal_end, vertical: :middle,
               width: parent && [ edge - parent[:x], 0 ].max, height: parent && geometry.height)
      else
        edge = geometry.right + geometry.horizontal_offset
        room = parent ? [ parent[:x] + parent[:width] - edge, 0 ].max : nil
        anchor(left: edge, top: geometry.center_y, horizontal: geometry.horizontal_start, vertical: :middle, width: room, height: parent && geometry.height)
      end
    end

    # The `inside*` positions share the size attributes (the parent exists: `width` is the box width, `height` its height).
    def inside(name, geometry)
      size = geometry.clamp_size
      near_left = geometry.x + geometry.horizontal_offset
      near_right = geometry.right - geometry.horizontal_offset
      near_top = geometry.y + geometry.vertical_offset
      near_bottom = geometry.bottom - geometry.vertical_offset
      center_x = geometry.center_x
      center_y = geometry.center_y
      horizontal_start = geometry.horizontal_start
      horizontal_end = geometry.horizontal_end
      vertical_start = geometry.vertical_start
      vertical_end = geometry.vertical_end
      case name
      when :inside_left then anchor(left: near_left, top: center_y, horizontal: horizontal_start, vertical: :middle, **size)
      when :inside_right then anchor(left: near_right, top: center_y, horizontal: horizontal_end, vertical: :middle, **size)
      when :inside_top then anchor(left: center_x, top: near_top, horizontal: :middle, vertical: vertical_start, **size)
      when :inside_bottom then anchor(left: center_x, top: near_bottom, horizontal: :middle, vertical: vertical_end, **size)
      when :inside_top_left then anchor(left: near_left, top: near_top, horizontal: horizontal_start, vertical: vertical_start, **size)
      when :inside_top_right then anchor(left: near_right, top: near_top, horizontal: horizontal_end, vertical: vertical_start, **size)
      when :inside_bottom_left then anchor(left: near_left, top: near_bottom, horizontal: horizontal_start, vertical: vertical_end, **size)
      else anchor(left: near_right, top: near_bottom, horizontal: horizontal_end, vertical: vertical_end, **size)
      end
    end

    # A position given as `{ x:, y: }` (numbers, or percents of the box).
    def free(position, geometry)
      return unless position.is_a?(Hash)

      across = position[:x] || position["x"]
      down = position[:y] || position["y"]
      return unless [ across, down ].all? { |value| value.is_a?(Numeric) || (value.is_a?(String) && value.end_with?("%")) }

      anchor(left: geometry.x + Chadcn::Chart::Cartesian::Value.percent(across, geometry.width),
             top: geometry.y + Chadcn::Chart::Cartesian::Value.percent(down, geometry.height), horizontal: :end, vertical: :end,
             **geometry.clamp_size)
    end

    def centered(geometry)
      anchor(left: geometry.center_x, top: geometry.center_y, horizontal: :middle, vertical: :middle, **geometry.clamp_size)
    end

    def anchor(left:, top:, horizontal:, vertical:, width:, height:)
      Result.new(x: left, y: top, horizontal_anchor: horizontal, vertical_anchor: vertical, width: width, height: height)
    end
  end
end

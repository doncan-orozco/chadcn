# frozen_string_literal: true

# Where a label sits around a box: recharts' `getCartesianPosition` (cartesian/getCartesianPosition.js) for the rectangular boxes of
# a bar, a data point or the plot, with `clamp: true`.
#
# @api private
module Chadcn::Chart::Cartesian::LabelPosition
  # The position of a label: the text anchor point, how the text hangs on it, and the width / height the label is clamped to (nil
  # when there is no parent box to clamp against).
  Result = Data.define(:x, :y, :horizontal_anchor, :vertical_anchor, :width, :height)

  CAMEL = ->(name) { name.to_s.gsub(/_([a-z])/) { Regexp.last_match(1).upcase } }

  private_constant :CAMEL

  class << self
    # @api private
    # @param box [Hash] `x`, `y`, `width`, `height` of the box the label belongs to
    # @param position [Symbol, String, Hash] `:top`, `:bottom`, `:left`, `:right`, `:inside_left` ... or `{ x:, y: }`; anything else centers
    # @param offset [Numeric] distance from the box
    # @param parent [Hash, nil] the box the label is clamped to (`x`, `y`, `width`, `height`)
    # @return [Result]
    def call(box:, position:, offset:, parent: nil)
      x, y, width, height = box.values_at(:x, :y, :width, :height)
      vertical_sign = height >= 0 ? 1 : -1
      horizontal_sign = width >= 0 ? 1 : -1
      geometry = { x: x, y: y, width: width, height: height, offset: offset, parent: parent,
                   v_offset: vertical_sign * offset, h_offset: horizontal_sign * offset,
                   v_end: vertical_sign.positive? ? :end : :start, v_start: vertical_sign.positive? ? :start : :end,
                   h_end: horizontal_sign.positive? ? :end : :start, h_start: horizontal_sign.positive? ? :start : :end }
      named(CAMEL.call(position), geometry) || free(position, geometry) || centered(geometry)
    end

    private

    def named(name, g)
      return outside(name, g) if %w[top bottom left right].include?(name)

      inside(name, g)
    end

    def outside(name, g)
      x = g[:x]
      y = g[:y]
      width = g[:width]
      height = g[:height]
      parent = g[:parent]
      case name
      when "top"
        build(x + (width / 2), y - g[:v_offset], :middle, g[:v_end], (parent && width), (parent && [ y - parent[:y], 0 ].max))
      when "bottom"
        build(x + (width / 2), y + height + g[:v_offset], :middle, g[:v_start], (parent && width), (parent && [ parent[:y] + parent[:height] - (y + height), 0 ].max))
      when "left"
        left = x - g[:h_offset]
        build(left, y + (height / 2), g[:h_end], :middle, (parent && [ left - parent[:x], 0 ].max), (parent && height))
      else
        right = x + width + g[:h_offset]
        build(right, y + (height / 2), g[:h_start], :middle, (parent && [ parent[:x] + parent[:width] - right, 0 ].max), (parent && height))
      end
    end

    # The `inside*` positions share the size attributes (the parent exists: `width` is the box width, `height` its height).
    def inside(name, g)
      x = g[:x]
      y = g[:y]
      width = g[:width]
      height = g[:height]
      size = g[:parent] ? [ width, height ] : [ nil, nil ]
      case name
      when "insideLeft" then build(x + g[:h_offset], y + (height / 2), g[:h_start], :middle, *size)
      when "insideRight" then build(x + width - g[:h_offset], y + (height / 2), g[:h_end], :middle, *size)
      when "insideTop" then build(x + (width / 2), y + g[:v_offset], :middle, g[:v_start], *size)
      when "insideBottom" then build(x + (width / 2), y + height - g[:v_offset], :middle, g[:v_end], *size)
      when "insideTopLeft" then build(x + g[:h_offset], y + g[:v_offset], g[:h_start], g[:v_start], *size)
      when "insideTopRight" then build(x + width - g[:h_offset], y + g[:v_offset], g[:h_end], g[:v_start], *size)
      when "insideBottomLeft" then build(x + g[:h_offset], y + height - g[:v_offset], g[:h_start], g[:v_end], *size)
      when "insideBottomRight" then build(x + width - g[:h_offset], y + height - g[:v_offset], g[:h_end], g[:v_end], *size)
      end
    end

    # A position given as `{ x:, y: }` (numbers, or percents of the box).
    def free(position, g)
      return unless position.is_a?(Hash)

      px = position[:x] || position["x"]
      py = position[:y] || position["y"]
      return unless [ px, py ].all? { |value| value.is_a?(Numeric) || (value.is_a?(String) && value.end_with?("%")) }

      size = g[:parent] ? [ g[:width], g[:height] ] : [ nil, nil ]
      build(g[:x] + Chadcn::Chart::Cartesian::Value.percent(px, g[:width]), g[:y] + Chadcn::Chart::Cartesian::Value.percent(py, g[:height]), :end, :end, *size)
    end

    def centered(g)
      size = g[:parent] ? [ g[:width], g[:height] ] : [ nil, nil ]
      build(g[:x] + (g[:width] / 2), g[:y] + (g[:height] / 2), :middle, :middle, *size)
    end

    def build(x, y, horizontal, vertical, width, height)
      Result.new(x: x, y: y, horizontal_anchor: horizontal, vertical_anchor: vertical, width: width, height: height)
    end
  end
end

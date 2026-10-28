# frozen_string_literal: true

# Which ticks of an axis are drawn and where their labels sit: recharts' `getTicks` (cartesian/getTicks.js, getEquidistantTicks.js,
# util/TickUtils.js). Labels that would overlap are dropped walking from the end (`:preserve_end`, the default) or the start, and the
# last label is pulled inside the chart. Sizes are the server's assumption ({Chadcn::Chart::Cartesian::Text}).
#
# @api private
module Chadcn::Chart::Cartesian::TickLayout
  # A tick of an axis: its position in the full list, the value on the axis, its pixel `coordinate`, the `offset` of the label from it
  # and, once laid out, the `tick_coord` the label is drawn at.
  Tick = Struct.new(:index, :value, :coordinate, :offset, :tick_coord, :shown, keyword_init: true)

  # The settings `getTicks` reads.
  Settings = Data.define(:orientation, :interval, :min_tick_gap, :formatter, :unit, :angle, :view_box)

  class << self
    # @api private
    # @param ticks [Array<Tick>] every tick of the axis, in axis order
    # @param settings [Settings]
    # @param text [Chadcn::Chart::Cartesian::Text]
    # @return [Array<Tick>] the ticks that are drawn, each with its `tick_coord`
    def visible(ticks, settings, text)
      return [] if ticks.empty?
      return every_nth(ticks, settings.interval.to_i + 1) if settings.interval.is_a?(Numeric)

      horizontal = %w[top bottom].include?(settings.orientation.to_s)
      size_of = size_function(settings, text, horizontal)
      sign = ticks.size >= 2 ? (ticks[1].coordinate - ticks[0].coordinate <=> 0) : 1
      start, finish = boundaries(settings.view_box, sign, horizontal)
      gap = settings.min_tick_gap
      case settings.interval.to_sym
      when :equidistant_preserve_start then equidistant(sign, start, finish, size_of, ticks, gap)
      when :equidistant_preserve_end then equidistant_preserve_end(sign, start, finish, size_of, ticks, gap)
      when :preserve_start then from_start(sign, start, finish, size_of, ticks, gap, false)
      when :preserve_start_end then from_start(sign, start, finish, size_of, ticks, gap, true)
      else from_end(sign, start, finish, size_of, ticks, gap)
      end
    end

    private

    # `getEveryNth`: every n-th tick starting with the first (n below 1 keeps none).
    def every_nth(ticks, step)
      return [] if step < 1

      ticks.each_slice(step).map(&:first)
    end

    def boundaries(view_box, sign, horizontal)
      origin = horizontal ? view_box[:x] : view_box[:y]
      extent = horizontal ? view_box[:width] : view_box[:height]
      sign == 1 ? [ origin, origin + extent ] : [ origin + extent, origin ]
    end

    # `getTickSize`: the label width (a horizontal axis, with the unit and the angle) or height (a vertical one).
    def size_function(settings, text, horizontal)
      lambda do |tick, index|
        label = settings.formatter ? settings.formatter.call(tick.value, index) : tick.value
        next text.line_height unless horizontal

        width = text.width(Chadcn::Chart::Cartesian::Value.text(label))
        unit_width = settings.unit ? text.width(settings.unit.to_s) : 0.0
        angled_width({ width: width + unit_width, height: text.line_height }, settings.angle)
      end
    end

    # `getAngledRectangleWidth`: the width of the widest horizontal line inside a rectangle turned by `angle` degrees.
    def angled_width(size, angle)
      radians = ((((angle % 180) + 180) % 180) * Math::PI) / 180
      threshold = Math.atan(size[:height] / size[:width])
      width = radians > threshold && radians < Math::PI - threshold ? size[:height] / Math.sin(radians) : size[:width] / Math.cos(radians)
      width.abs
    end

    def visible?(sign, position, size, start, finish)
      return false if (sign * position) < (sign * start) || (sign * position) > (sign * finish)

      half = size / 2
      behind_start = (sign * (position - (sign * half) - start)).negative?
      past_end = (sign * (position + (sign * half) - finish)).positive?
      !(behind_start || past_end)
    end

    # `getTicksEnd`
    def from_end(sign, start, finish, size_of, ticks, min_gap)
      result = ticks.map(&:dup)
      (result.size - 1).downto(0) do |i|
        entry = result[i]
        size = size_of.call(entry, i)
        entry.tick_coord = i == result.size - 1 ? last_coord(sign, entry, size, finish) : entry.coordinate
        next unless visible?(sign, entry.tick_coord, size, start, finish)

        finish = entry.tick_coord - (sign * ((size / 2) + min_gap))
        entry.shown = true
      end
      result.select(&:shown)
    end

    def last_coord(sign, entry, size, finish)
      gap = sign * (entry.coordinate + (sign * size / 2) - finish)
      gap.positive? ? entry.coordinate - (gap * sign) : entry.coordinate
    end

    # `getTicksStart`; `preserve_end` first tries to keep the last tick.
    def from_start(sign, start, finish, size_of, ticks, min_gap, preserve_end)
      result = ticks.map(&:dup)
      count = result.size
      if preserve_end
        tail = result.last
        size = size_of.call(tail, count - 1)
        tail.tick_coord = last_coord(sign, tail, size, finish)
        if visible?(sign, tail.tick_coord, size, start, finish)
          finish = tail.tick_coord - (sign * ((size / 2) + min_gap))
          tail.shown = true
        end
        count -= 1
      end
      count.times do |i|
        entry = result[i]
        size = size_of.call(entry, i)
        entry.tick_coord = i.zero? ? first_coord(sign, entry, size, start) : entry.coordinate
        next unless visible?(sign, entry.tick_coord, size, start, finish)

        start = entry.tick_coord + (sign * ((size / 2) + min_gap))
        entry.shown = true
      end
      result.select(&:shown)
    end

    def first_coord(sign, entry, size, start)
      gap = sign * (entry.coordinate - (sign * size / 2) - start)
      gap.negative? ? entry.coordinate - (gap * sign) : entry.coordinate
    end

    # `getEquidistantTicks`: every step-th tick, the smallest step at which they all fit.
    def equidistant(sign, start, finish, size_of, ticks, min_gap)
      first_start = start
      index = 0
      step = 1
      while step <= ticks.size
        entry = ticks[index]
        return every_nth(ticks, step) if entry.nil?

        size = size_of.call(entry, index)
        if index.zero? || visible?(sign, entry.coordinate, size, start, finish)
          start = entry.coordinate + (sign * ((size / 2) + min_gap))
          index += step
        else
          index = 0
          start = first_start
          step += 1
        end
      end
      []
    end

    # `getEquidistantPreserveEndTicks`: the sequence ends on the last tick.
    def equidistant_preserve_end(sign, first_start, finish, size_of, ticks, min_gap)
      count = ticks.size
      (1..count).each do |step|
        offset = (count - 1) % step
        start = first_start
        indexes = offset.step(count - 1, step).to_a
        fits = indexes.all? do |index|
          entry = ticks[index]
          size = size_of.call(entry, index)
          next false unless index == offset || visible?(sign, entry.coordinate, size, start, finish)

          start = entry.coordinate + (sign * ((size / 2) + min_gap))
          true
        end
        return indexes.map { |index| ticks[index] } if fits
      end
      []
    end
  end
end

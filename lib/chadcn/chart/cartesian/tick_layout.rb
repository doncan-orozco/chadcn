# frozen_string_literal: true

# Which ticks of an axis are drawn and where their labels sit: recharts' `getTicks` (cartesian/getTicks.js, getEquidistantTicks.js,
# util/TickUtils.js). Labels that would overlap are dropped walking from the end (`:preserve_end`, the default) or the start, and the
# last label is pulled inside the chart. Sizes are the server's assumption ({Chadcn::Chart::Cartesian::Text}).
#
# @api private
module Chadcn::Chart::Cartesian::TickLayout
  # A tick of an axis: its position in the full list, the value on the axis, its pixel `coordinate`, the `offset` of the label from it
  # and, once laid out, the `tick_coord` the label is drawn at.
  Tick = Data.define(:index, :value, :coordinate, :offset, :tick_coord) do
    def initialize(index:, value:, coordinate:, offset:, tick_coord: nil) = super
  end

  # The settings `getTicks` reads.
  Settings = Data.define(:orientation, :interval, :min_tick_gap, :formatter, :unit, :angle, :view_box)

  # What every pass walks with: the direction of the axis (`sign`), the span the labels must stay inside, how wide a label is and the
  # least room between two labels.
  Pass = Data.define(:sign, :start, :finish, :size_of, :gap) do
    # Whether a label of `size` centered on `position` lies inside the span left between `start` and `finish`.
    def fits?(position, size, start:, finish:)
      return false if (sign * position) < (sign * start) || (sign * position) > (sign * finish)

      half = size / 2
      behind_start = (sign * (position - (sign * half) - start)).negative?
      past_end = (sign * (position + (sign * half) - finish)).positive?
      !(behind_start || past_end)
    end

    # Where the span starts after a label of `size` centered on `position`.
    def start_after(position, size) = position + (sign * ((size / 2) + gap))

    # Where the span ends before a label of `size` centered on `position`.
    def finish_before(position, size) = position - (sign * ((size / 2) + gap))
  end

  private_constant :Pass

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
      pass = Pass.new(sign: sign, start: start, finish: finish, size_of: size_of, gap: settings.min_tick_gap)
      case settings.interval.to_sym
      when :equidistant_preserve_start then evenly_spaced_from_start(ticks, pass)
      when :equidistant_preserve_end then evenly_spaced_ending_on_last(ticks, pass)
      when :preserve_start then drop_overlaps_from_start(ticks, pass, keep_last: false)
      when :preserve_start_end then drop_overlaps_from_start(ticks, pass, keep_last: true)
      else drop_overlaps_from_end(ticks, pass)
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

    # `getTicksEnd`
    def drop_overlaps_from_end(ticks, pass)
      finish = pass.finish
      last = ticks.size - 1
      kept = []
      last.downto(0) do |index|
        tick = ticks[index]
        size = pass.size_of.call(tick, index)
        coord = index == last ? last_coord(pass, tick, size, finish: finish) : tick.coordinate
        next unless pass.fits?(coord, size, start: pass.start, finish: finish)

        finish = pass.finish_before(coord, size)
        kept.unshift(tick.with(tick_coord: coord))
      end
      kept
    end

    def last_coord(pass, tick, size, finish:)
      overshoot = pass.sign * (tick.coordinate + (pass.sign * size / 2) - finish)
      overshoot.positive? ? tick.coordinate - (overshoot * pass.sign) : tick.coordinate
    end

    # `getTicksStart`; `keep_last` (`preserve_start_end`) first tries to keep the last tick.
    def drop_overlaps_from_start(ticks, pass, keep_last:)
      start = pass.start
      finish = pass.finish
      count = ticks.size
      kept = []
      tail = nil
      if keep_last
        size = pass.size_of.call(ticks.last, count - 1)
        coord = last_coord(pass, ticks.last, size, finish: finish)
        if pass.fits?(coord, size, start: start, finish: finish)
          finish = pass.finish_before(coord, size)
          tail = ticks.last.with(tick_coord: coord)
        end
        count -= 1
      end
      count.times do |index|
        tick = ticks[index]
        size = pass.size_of.call(tick, index)
        coord = index.zero? ? first_coord(pass, tick, size, start: start) : tick.coordinate
        next unless pass.fits?(coord, size, start: start, finish: finish)

        start = pass.start_after(coord, size)
        kept << tick.with(tick_coord: coord)
      end
      tail ? kept << tail : kept
    end

    def first_coord(pass, tick, size, start:)
      overshoot = pass.sign * (tick.coordinate - (pass.sign * size / 2) - start)
      overshoot.negative? ? tick.coordinate - (overshoot * pass.sign) : tick.coordinate
    end

    # `getEquidistantTicks`: every step-th tick, the smallest step at which they all fit.
    def evenly_spaced_from_start(ticks, pass)
      start = pass.start
      index = 0
      step = 1
      while step <= ticks.size
        tick = ticks[index]
        return every_nth(ticks, step) if tick.nil?

        size = pass.size_of.call(tick, index)
        if index.zero? || pass.fits?(tick.coordinate, size, start: start, finish: pass.finish)
          start = pass.start_after(tick.coordinate, size)
          index += step
        else
          index = 0
          start = pass.start
          step += 1
        end
      end
      []
    end

    # `getEquidistantPreserveEndTicks`: the sequence ends on the last tick.
    def evenly_spaced_ending_on_last(ticks, pass)
      count = ticks.size
      (1..count).each do |step|
        offset = (count - 1) % step
        start = pass.start
        indexes = offset.step(count - 1, step).to_a
        fits = indexes.all? do |index|
          tick = ticks[index]
          size = pass.size_of.call(tick, index)
          next false unless index == offset || pass.fits?(tick.coordinate, size, start: start, finish: pass.finish)

          start = pass.start_after(tick.coordinate, size)
          true
        end
        return indexes.map { |index| ticks[index] } if fits
      end
      []
    end
  end
end

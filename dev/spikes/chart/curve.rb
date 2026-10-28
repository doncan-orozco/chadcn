# frozen_string_literal: true

require_relative "scale"

module ChartSpike
  # d3-path 3.1 `pathRound(3)`: every number is Math.round(v * 1000) / 1000 (recharts' line()/area() use the default digits of 3).
  class PathBuilder
    def initialize = @d = +""

    def move_to(x, y) = @d << "M#{n(x)},#{n(y)}"
    def line_to(x, y) = @d << "L#{n(x)},#{n(y)}"
    def bezier_to(x1, y1, x2, y2, x, y) = @d << "C#{[x1, y1, x2, y2, x, y].map { |v| n(v) }.join(',')}"
    def to_s = @d.dup

    private

    def n(value) = Num.js(Num.round(value, 3))
  end

  # d3-shape curveMonotoneX (src/curve/monotone.js), driven the way d3 line() drives a curve for defined points.
  class MonotoneX
    def self.path(points)
      new(points).path
    end

    def initialize(points)
      @points = points
      @ctx = PathBuilder.new
    end

    def path
      @x0 = @x1 = @y0 = @y1 = @t0 = Float::NAN
      @state = 0
      @points.each { |x, y| point(x.to_f, y.to_f) }
      line_end
      @ctx.to_s
    end

    private

    def sign(value) = value.negative? ? -1 : 1

    def divide(numerator, denominator)
      # JS x / 0 is +-Infinity; the spike data never has coincident x, kept for fidelity of the dx == 0 branch.
      denominator.zero? ? numerator.to_f / 0.0 : numerator / denominator
    end

    def slope3(x2, y2)
      h0 = @x1 - @x0
      h1 = x2 - @x1
      s0 = divide(@y1 - @y0, h0)
      s1 = divide(y2 - @y1, h1)
      p = ((s0 * h1) + (s1 * h0)) / (h0 + h1)
      value = (sign(s0) + sign(s1)) * [s0.abs, s1.abs, 0.5 * p.abs].min
      value.nan? ? 0.0 : value
    end

    def slope2(t)
      h = @x1 - @x0
      h.zero? ? t : (((3 * (@y1 - @y0) / h) - t) / 2)
    end

    def segment(t0, t1)
      dx = (@x1 - @x0) / 3
      @ctx.bezier_to(@x0 + dx, @y0 + (dx * t0), @x1 - dx, @y1 - (dx * t1), @x1, @y1)
    end

    def point(x, y)
      t1 = Float::NAN
      return if x == @x1 && y == @y1 # coincident points are ignored

      case @state
      when 0
        @state = 1
        @ctx.move_to(x, y)
      when 1
        @state = 2
      when 2
        @state = 3
        t1 = slope3(x, y)
        segment(slope2(t1), t1)
      else
        t1 = slope3(x, y)
        segment(@t0, t1)
      end
      @x0 = @x1
      @x1 = x
      @y0 = @y1
      @y1 = y
      @t0 = t1
    end

    def line_end
      case @state
      when 2 then @ctx.line_to(@x1, @y1)
      when 3 then segment(@t0, slope2(@t0))
      end
    end
  end

  # d3-shape stack() with the default order (series order) and offset (none): rows of [y0, y1] per series.
  module Stack
    module_function

    def series(data, keys)
      running = Array.new(data.size, 0.0)
      keys.to_h do |key|
        rows = data.each_with_index.map do |row, i|
          y0 = running[i]
          running[i] = y0 + row.fetch(key)
          [y0, running[i]]
        end
        [key, rows]
      end
    end
  end
end

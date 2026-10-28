# frozen_string_literal: true

# Throwaway math of the chart spike (decision: dev/decisions/chart.md). Pieces ported from d3 and recharts, each with its source:
#   d3-array 3.2.4  src/ticks.js (tickSpec, ticks, tickIncrement)       d3-scale 4.0.2 src/linear.js (nice, interpolation), src/band.js
#   d3-shape 3.2.0  src/curve/monotone.js (curveMonotoneX), src/stack.js d3-path 3.1.0 src/path.js (digits rounding)
#   recharts 3.8.0  es6/util/scale/getNiceTickValues.js (the algorithm recharts really uses for a numeric axis; d3 ticks/nice are NOT used)
module ChartSpike
  # JavaScript number formatting and rounding, so emitted strings equal React DOM's.
  module Num
    module_function

    # Number#toString for the finite values a chart produces.
    def js(value)
      v = value.to_f
      return "0" if v.zero?
      return v.to_i.to_s if v == v.truncate && v.abs < 1e15

      s = v.to_s
      raise ArgumentError, "exponent notation is not produced by the spike data: #{s}" if s.include?("e")

      s
    end

    # Math.round(v * 10**digits) / 10**digits (JS rounds half up), -0 normalized.
    def round(value, digits)
      factor = 10**digits
      rounded = ((value * factor) + 0.5).floor.to_f / factor
      rounded.zero? ? 0.0 : rounded
    end
  end

  module D3
    E10 = Math.sqrt(50)
    E5 = Math.sqrt(10)
    E2 = Math.sqrt(2)

    module_function

    # d3-array ticks.js tickSpec -> [i1, i2, inc]
    def tick_spec(start, stop, count)
      step = (stop - start) / [0, count].max.to_f
      power = Math.log10(step).floor
      error = step / (10.0**power)
      factor = if error >= E10 then 10
               elsif error >= E5 then 5
               elsif error >= E2 then 2
               else 1
               end
      if power.negative?
        inc = (10.0**-power) / factor
        i1 = (start * inc).round
        i2 = (stop * inc).round
        i1 += 1 if i1 / inc < start
        i2 -= 1 if i2 / inc > stop
        inc = -inc
      else
        inc = (10.0**power) * factor
        i1 = (start / inc).round
        i2 = (stop / inc).round
        i1 += 1 if i1 * inc < start
        i2 -= 1 if i2 * inc > stop
      end
      return tick_spec(start, stop, count * 2) if i2 < i1 && count >= 0.5 && count < 2

      [i1, i2, inc]
    end

    def tick_increment(start, stop, count) = tick_spec(start.to_f, stop.to_f, count)[2]

    # d3-array ticks(start, stop, count), ascending case.
    def ticks(start, stop, count)
      return [] unless count.positive?
      return [start] if start == stop

      i1, i2, inc = tick_spec(start.to_f, stop.to_f, count)
      return [] unless i2 >= i1

      (i1..i2).map { |i| inc.negative? ? i / -inc : i * inc }
    end

    # d3-scale linear.nice(count) on an ascending domain.
    def nice(start, stop, count)
      start = start.to_f
      stop = stop.to_f
      prestep = nil
      10.times do
        step = tick_increment(start, stop, count)
        return [start, stop] if step == prestep

        if step.positive?
          start = (start / step).floor * step
          stop = (stop / step).ceil * step
        elsif step.negative?
          start = (start * step).ceil / step
          stop = (stop * step).floor / step
        else
          break
        end
        prestep = step
      end
      [start, stop]
    end
  end

  # recharts util/scale/getNiceTickValues.js with the adaptive step (niceTicks "auto"), in exact rational arithmetic (it uses decimal.js-light).
  module NiceTicks
    module_function

    def rational(value) = value.is_a?(Rational) ? value : Rational(value.to_s)

    def digit_count(value) = value.zero? ? 1 : Math.log10(value.abs.to_f).floor + 1

    def adaptive_step(rough, allow_decimals, correction)
      return 0r if rough <= 0

      count = digit_count(rough)
      magnitude = 10r**count
      ratio = rough / magnitude
      ratio_scale = count == 1 ? Rational(1, 10) : Rational(5, 100)
      step = (((ratio / ratio_scale).to_f.ceil + correction) * ratio_scale) * magnitude
      allow_decimals ? step : Rational(step.ceil)
    end

    def calculate_step(min, max, tick_count, allow_decimals, correction = 0)
      step = adaptive_step((rational(max) - rational(min)) / (tick_count - 1), allow_decimals, correction)
      min = rational(min)
      max = rational(max)
      middle = if min <= 0 && max >= 0
                 0r
               else
                 ((min + max) / 2 / step).truncate * step # middle - middle.mod(step)
               end
      below = ((middle - min) / step).ceil
      up = ((max - middle) / step).ceil
      scale_count = below + up + 1
      return calculate_step(min, max, tick_count, allow_decimals, correction + 1) if scale_count > tick_count

      if scale_count < tick_count
        extra = tick_count - scale_count
        max.positive? ? up += extra : below += extra
      end
      [step, middle - (below * step), middle + (up * step)]
    end

    # getNiceTickValues([min, max], tickCount, allowDecimals); the min == max case is out of the spike's scope.
    def values(min, max, tick_count = 5, allow_decimals: true)
      raise ArgumentError, "single-value domains are not covered by the spike" if min == max

      step, tick_min, tick_max = calculate_step(*[min, max].minmax, [tick_count, 2].max, allow_decimals)
      limit = tick_max + (Rational(1, 10) * step)
      result = []
      num = tick_min
      while num < limit
        result << num.to_f
        num += step
      end
      result
    end
  end

  # d3 scaleLinear: normalize then interpolateNumber(a, b)(t) = a * (1 - t) + b * t (same operation order, so floats equal).
  class Linear
    attr_reader :domain, :range

    def initialize(domain, range)
      @domain = domain.map(&:to_f)
      @range = range.map(&:to_f)
    end

    def map(value)
      d0, d1 = @domain
      t = (value - d0) / (d1 - d0)
      r0, r1 = @range
      (r0 * (1 - t)) + (r1 * t)
    end
  end

  # d3 scaleBand (padding 0, align 0.5), and scalePoint when point: true (paddingInner 1, so bandwidth 0).
  class Band
    attr_reader :bandwidth

    def initialize(count, range, point: false)
      start, stop = range.map(&:to_f)
      padding_inner = point ? 1.0 : 0.0
      @step = (stop - start) / [1, count - padding_inner].max
      @start = start + ((stop - start - (@step * (count - padding_inner))) * 0.5)
      @bandwidth = @step * (1 - padding_inner)
    end

    attr_reader :step

    # Left edge of the i-th category.
    def map(index) = @start + (@step * index)

    # recharts places a category tick at the middle of its band (offset = bandwidth / 2).
    def tick(index) = map(index) + (@bandwidth / 2)
  end
end

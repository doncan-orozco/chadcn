# frozen_string_literal: true

# d3-shape `area()` with the baseline handling of recharts' shape/Curve.js `getPath`: the top line is drawn forward with the chosen
# curve, then the baseline backwards with the same curve, per run of defined points. Points are `[x, y]` pairs.
#
# @api private
module Chadcn::Chart::Shape::Area
  # A point of the area with its baseline point (required only for an array baseline) and the four coordinates d3 asks for:
  # `edge` is [x0, y0, x1, y1], the baseline side then the top line; nil for an undefined point.
  Item = Data.define(:point, :base, :base_required, :edge)

  private_constant :Item

  class << self
    # The `d` attribute of an area, or nil when nothing is drawn.
    #
    # With a numeric `baseline` the area closes on that constant (a y for horizontal layouts, an x for vertical ones). With an array
    # `baseline` (one `[x, y]` per point, same order) the area closes on those points; a point is drawable only when it and its
    # baseline point are defined.
    #
    # @api private
    # @param points [Array<Array(Numeric, Numeric), nil>]
    # @param baseline [Numeric, Array<Array(Numeric, Numeric), nil>]
    # @param type [Symbol, String] one of {Chadcn::Chart::Shape::Curve::TYPES}
    # @param layout [Symbol, String] :horizontal (default) or :vertical
    # @param connect_nulls [Boolean] drop undefined points before drawing
    # @param defined [#call, nil] `->(point) { boolean }` replacing the finite-coordinates test, applied to points and baseline points
    # @param digits [Integer, nil] decimals kept in the path numbers
    # @return [String, nil]
    # @raise [ArgumentError] on an unknown type or layout, or a baseline that is neither a number nor an array
    def path(points, baseline:, type: :linear, layout: :horizontal, connect_nulls: false, defined: nil,
             digits: Chadcn::Chart::Shape::Path::DEFAULT_DIGITS)
      curve = Chadcn::Chart::Shape::Curve
      defined ||= curve.method(:drawable?)
      items = pair_with_baseline(points, baseline, curve.vertical?(layout))
      drawable = ->(item) { defined.call(item.point) && (!item.base_required || (item.base && defined.call(item.base))) }
      items = items.select(&drawable) if connect_nulls
      context = Chadcn::Chart::Shape::Path.new(digits: digits)
      draw(items, drawable, curve.build(type, context, layout: layout))
      context.d
    end

    private

    # Every point with its baseline: the point at the same index of an array baseline, or the one number of a constant baseline.
    def pair_with_baseline(points, baseline, vertical)
      case baseline
      when Array
        points.each_with_index.map do |point, index|
          base = baseline[index]
          Item.new(point: point, base: base, base_required: true, edge: (edge_of(point, base[0], base[1], vertical) if point && base))
        end
      when Numeric
        points.map do |point|
          Item.new(point: point, base: nil, base_required: false, edge: (edge_of(point, baseline, baseline, vertical) if point))
        end
      else raise ArgumentError, "baseline must be a number or an array of points, got #{baseline.inspect}"
      end
    end

    # [x0, y0, x1, y1]: the baseline side (an x for vertical layouts, a y for horizontal ones) then the point of the top line.
    def edge_of(point, base_x, base_y, vertical)
      vertical ? [ base_x, point[1], point[0], point[1] ] : [ point[0], base_y, point[0], point[1] ]
    end

    # d3's area loop: the top line point by point, then at the end of each run the baseline from its last point back to its first.
    def draw(items, drawable, output)
      baseline_points = []
      Chadcn::Chart::Shape::Curve.each_segment(items, drawable) do |current, event|
        case event
        when :start
          baseline_points = []
          output.area_start
          output.line_start
        when :end
          output.line_end
          output.line_start
          baseline_points.reverse_each { |x, y| output.point(x, y) }
          output.line_end
          output.area_end
        else
          x0, y0, x1, y1 = current.edge
          baseline_points << [ x0, y0 ]
          output.point(x1, y1)
        end
      end
    end
  end
end

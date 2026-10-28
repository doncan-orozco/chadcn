# frozen_string_literal: true

# d3-shape `area()` with the baseline handling of recharts' shape/Curve.js `getPath`: the top line is drawn forward with the chosen
# curve, then the baseline backwards with the same curve, per run of defined points. Points are `[x, y]` pairs.
#
# @api private
module Chadcn::Chart::Shape::Area
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
  def self.path(points, baseline:, type: :linear, layout: :horizontal, connect_nulls: false, defined: nil, digits: Chadcn::Chart::Shape::Path::DEFAULT_DIGITS)
    curve = Chadcn::Chart::Shape::Curve
    defined ||= curve.method(:drawable?)
    vertical = curve.vertical?(layout)
    items = pair_with_baseline(points, baseline, vertical)
    drawable = ->(item) { item && defined.call(item[:point]) && (!item[:base_required] || (item[:base] && defined.call(item[:base]))) }
    items = items.select(&drawable) if connect_nulls
    context = Chadcn::Chart::Shape::Path.new(digits: digits)
    output = curve.build(type, context, layout: layout)
    draw(items, drawable, output)
    context.d
  end

  # Items carrying the point, its baseline point (required only for an array baseline) and the four coordinates d3 asks for:
  # `edge` is [x0, y0, x1, y1], the baseline side then the top line.
  #
  # @api private
  # @return [Array<Hash>]
  def self.pair_with_baseline(points, baseline, vertical)
    case baseline
    when Array then points.each_with_index.map { |point, index| array_item(point, baseline[index], vertical) }
    when Numeric then points.map { |point| constant_item(point, baseline, vertical) }
    else raise ArgumentError, "baseline must be a number or an array of points, got #{baseline.inspect}"
    end
  end

  # @api private
  # @return [Hash]
  def self.array_item(point, base, vertical)
    return { point: point, base: base, base_required: true, edge: nil } unless point && base

    edge = vertical ? [ base[0], point[1], point[0], point[1] ] : [ point[0], base[1], point[0], point[1] ]
    { point: point, base: base, base_required: true, edge: edge }
  end

  # @api private
  # @return [Hash]
  def self.constant_item(point, base, vertical)
    return { point: point, base: nil, base_required: false, edge: nil } unless point

    edge = vertical ? [ base, point[1], point[0], point[1] ] : [ point[0], base, point[0], point[1] ]
    { point: point, base: nil, base_required: false, edge: edge }
  end

  # d3's area loop: the top line point by point, then at the end of each run the baseline from its last point back to its first.
  #
  # @api private
  # @return [void]
  def self.draw(items, drawable, output)
    baseline = []
    Chadcn::Chart::Shape::Curve.each_segment(items, drawable) do |item, event|
      case event
      when :start
        baseline = []
        output.area_start
        output.line_start
      when :end
        output.line_end
        output.line_start
        baseline.reverse_each { |x, y| output.point(x, y) }
        output.line_end
        output.area_end
      else
        x0, y0, x1, y1 = item[:edge]
        baseline << [ x0, y0 ]
        output.point(x1, y1)
      end
    end
  end
end

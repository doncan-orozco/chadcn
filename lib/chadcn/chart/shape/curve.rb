# frozen_string_literal: true

# Curve factories and the `line` generator of d3-shape, with the point handling of recharts' shape/Curve.js `getPath`. Points are
# `[x, y]` pairs; a point is "defined" when both coordinates are finite numbers (a nil or non-finite coordinate breaks the line
# into segments, or is dropped with `connect_nulls`).
#
# @api private
module Chadcn::Chart::Shape::Curve
  # Curve names accepted by {.build}. `:monotone` and `:bump` follow the layout (X for horizontal, Y for vertical), like recharts.
  TYPES = %i[
    linear linear_closed monotone monotone_x monotone_y natural step step_before step_after basis basis_closed basis_open bump bump_x bump_y
  ].freeze

  # Chadcn::Chart::Shape::Curve::Interpolator for a curve name.
  #
  # @api private
  # @param type [Symbol, String] one of {TYPES}
  # @param context [Chadcn::Chart::Shape::Path] receives the segments
  # @param layout [Symbol, String] :horizontal (default) or :vertical
  # @return [Chadcn::Chart::Shape::Curve::Interpolator]
  # @raise [ArgumentError] on an unknown type or layout
  def self.build(type, context, layout: :horizontal)
    vertical = vertical?(layout)
    name = type.to_sym
    case name
    when :linear then Linear.new(context)
    when :linear_closed then LinearClosed.new(context)
    when :monotone then (vertical ? MonotoneY : MonotoneX).new(context)
    when :monotone_x then MonotoneX.new(context)
    when :monotone_y then MonotoneY.new(context)
    when :natural then Natural.new(context)
    when :step then Step.new(context, 0.5)
    when :step_before then Step.new(context, 0)
    when :step_after then Step.new(context, 1)
    when :basis then Basis.new(context)
    when :basis_closed then BasisClosed.new(context)
    when :basis_open then BasisOpen.new(context)
    when :bump then Bump.new(context, horizontal: !vertical)
    when :bump_x then Bump.new(context, horizontal: true)
    when :bump_y then Bump.new(context, horizontal: false)
    else raise ArgumentError, "unknown curve type #{type.inspect}, expected one of #{TYPES.join(', ')}"
    end
  end

  # d3 `line()` over `[x, y]` points: the `d` attribute of the path, or nil when nothing is drawn. Undefined points split the line into
  # segments (a lone point is drawn only by curves that close single points, as in d3); `connect_nulls` drops them instead.
  #
  # @api private
  # @param points [Array<Array(Numeric, Numeric), nil>]
  # @param type [Symbol, String] one of {TYPES}
  # @param layout [Symbol, String] :horizontal or :vertical (selects monotone and bump flavors)
  # @param connect_nulls [Boolean] drop undefined points before drawing
  # @param defined [#call, nil] `->(point) { boolean }` replacing the finite-coordinates test
  # @param digits [Integer, nil] decimals kept in the path numbers (d3's default is 3)
  # @return [String, nil]
  def self.line(points, type: :linear, layout: :horizontal, connect_nulls: false, defined: nil, digits: Chadcn::Chart::Shape::Path::DEFAULT_DIGITS)
    defined ||= method(:drawable?)
    kept = connect_nulls ? points.select { |point| defined.call(point) } : points
    path = Chadcn::Chart::Shape::Path.new(digits: digits)
    output = build(type, path, layout: layout)
    each_segment(kept, defined) do |segment, event|
      case event
      when :start then output.line_start
      when :end then output.line_end
      else output.point(*segment)
      end
    end
    path.d
  end

  # The recharts test for a drawable point (`isWellBehavedNumber` on both coordinates).
  #
  # @api private
  # @param point [Array(Numeric, Numeric), nil]
  # @return [Boolean]
  def self.drawable?(point)
    !point.nil? && well_behaved?(point[0]) && well_behaved?(point[1])
  end

  # The recharts `isWellBehavedNumber` test of one coordinate: a finite Numeric.
  #
  # @api private
  # @return [Boolean]
  def self.well_behaved?(value) = value.is_a?(Numeric) && value.finite?
  private_class_method :well_behaved?

  # @api private
  # @param layout [Symbol, String]
  # @return [Boolean]
  # @raise [ArgumentError] unless the layout is horizontal or vertical
  def self.vertical?(layout)
    case layout.to_s
    when "vertical" then true
    when "horizontal" then false
    else raise ArgumentError, "unknown layout #{layout.inspect}, expected :horizontal or :vertical"
    end
  end

  # d3's walk over the data: yields :start before the first defined point of a run, the point itself, and :end after its last.
  # The loop runs one past the end so the last run is closed.
  #
  # @api private
  # @yieldparam item [Object] the data item (nil for the events)
  # @yieldparam event [Symbol] :start, :end or :point
  # @return [void]
  def self.each_segment(data, defined)
    inside = false
    (0..data.size).each do |index|
      item = data[index] if index < data.size
      drawable = index < data.size && defined.call(item)
      if drawable != inside
        inside = drawable
        yield nil, inside ? :start : :end
      end
      yield item, :point if inside
    end
  end
end

# frozen_string_literal: true

# The settings of one `PolarAngleAxis` / `PolarRadiusAxis`, validated and normalized once: recharts' `defaultPolarAngleAxisProps` /
# `defaultPolarRadiusAxisProps` (polar/defaultPolarAngleAxisProps.js, polar/defaultPolarRadiusAxisProps.js) plus the values the declaration
# gave. An axis nobody declared is {.implicit} (state/selectors/polarAxisSelectors.js:10-40) and is not drawn.
#
# `kind` is `:angle` or `:radius`; `type` is `:auto` until the chart layout decides it. `tick`, `tick_line` and `axis_line` are true, false
# or a Hash of attributes; `attrs` land on the axis line and the ticks.
#
# @api private
Chadcn::Chart::Polar::AxisSettings = Data.define(
  :kind, :id, :data_key, :type, :domain, :reversed, :allow_decimals, :tick_count, :tick_formatter, :tick, :tick_line, :axis_line,
  :axis_line_type, :tick_size, :orientation, :angle, :stroke, :attrs
) do
  class << self
    include Chadcn::Chart::Cartesian::Choice

    # The settings of a declared axis.
    #
    # @api private
    # @param kind [Symbol] :angle or :radius
    # @return [AxisSettings]
    # @raise [ArgumentError] on a value outside the supported ones
    def build(kind, **options)
      options[:type] = choice(:type, options[:type], %i[auto number category])
      options[:orientation] = choice(:orientation, options[:orientation], kind == :angle ? %i[inner outer] : %i[left right middle])
      options[:axis_line_type] = choice(:axis_line_type, options[:axis_line_type], %i[polygon circle])
      options[:tick_formatter] = Chadcn::Chart::Cartesian::Formatter.resolve(options[:tick_formatter])
      options[:domain] = domain(options[:domain])
      options[:id] = options.delete(:axis_id)
      new(kind: kind, **options)
    end

    # The axis recharts uses when none is declared (`implicitAngleAxis` / `implicitRadiusAxis`).
    #
    # @api private
    # @param kind [Symbol] :angle or :radius
    # @param id [Object] the axis id, 0 by default
    # @return [AxisSettings]
    def implicit(kind, id = 0)
      new(kind: kind, id: id, data_key: nil, type: :auto, domain: nil, reversed: false, allow_decimals: false, tick_count: (5 if kind == :radius),
          tick_formatter: nil, tick: true, tick_line: true, axis_line: true, axis_line_type: :polygon, tick_size: 8,
          orientation: kind == :angle ? :outer : :right, angle: 0, stroke: nil, attrs: {})
    end

    private

    # `[min, max]` where each is a number, `:auto`, `:data_min`, `:data_max`, a "dataMin - 5" / "dataMax + 5" string or a callable.
    def domain(value)
      return if value.nil?
      raise ArgumentError, "domain: must be [min, max] (got #{value.inspect})" unless value.is_a?(Array) && value.size == 2

      value.map { |bound| domain_bound(bound) }.freeze
    end

    def domain_bound(bound)
      case bound
      when :auto, "auto" then "auto"
      when :data_min, "dataMin" then "dataMin"
      when :data_max, "dataMax" then "dataMax"
      else bound
      end
    end
  end

  # @api private
  # @return [Boolean] whether this is the angle axis
  def angle? = kind == :angle

  # The same settings as the cartesian axis resolution reads (domain, nice ticks, scale), for the layout `type` decided: the angle axis is
  # the `x` of that resolution and the radius axis its `y`. The angle axis has no nice ticks (state/selectors/polarAxisSelectors.js:10:
  # `tickCount: undefined`) and never lists a category twice (`allowDuplicatedCategory: false`, polar/PolarAngleAxis.js:250).
  #
  # @api private
  # @param type [Symbol] :category or :number
  # @return [Chadcn::Chart::Cartesian::AxisSettings]
  def to_cartesian(type)
    Chadcn::Chart::Cartesian::AxisSettings.build(
      angle? ? :x : :y,
      data_key: data_key, type: type, hide: true, size: 0, orientation: angle? ? :bottom : :left, tick: true, tick_line: true, axis_line: true,
      tick_size: 0, tick_margin: 0, tick_count: tick_count || 10, tick_formatter: nil, interval: :preserve_end, min_tick_gap: 0,
      mirror: false, reversed: reversed, padding: nil, domain: domain, allow_decimals: allow_decimals,
      allow_duplicated_category: !angle?, allow_data_overflow: false, include_hidden: false, nice_ticks: angle? ? :none : :auto, angle: 0,
      unit: nil, ticks: nil, scale: :auto, stroke: "#666", axis_id: id, name: nil, attrs: {}
    )
  end
end

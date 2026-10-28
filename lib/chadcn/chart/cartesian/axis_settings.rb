# frozen_string_literal: true

# The settings of one `XAxis` / `YAxis`, validated and normalized once: recharts' `xAxisDefaultProps` / `yAxisDefaultProps` plus the
# values the declaration gave. An axis nobody declared is {.implicit}: hidden, with recharts' implicit defaults
# (state/selectors/axisSelectors.js:44-119).
#
# `size` is the height of an x axis and the width of a y axis. `tick` is true, false or a Hash of attributes for every label.
#
# @api private
class Chadcn::Chart::Cartesian::AxisSettings < Data.define(
  :kind, :id, :data_key, :type, :hide, :size, :orientation, :tick, :tick_line, :axis_line, :tick_size, :tick_margin, :tick_count,
  :tick_formatter, :interval, :min_tick_gap, :mirror, :reversed, :padding, :domain, :allow_decimals, :allow_duplicated_category,
  :allow_data_overflow, :include_hidden, :nice_ticks, :angle, :unit, :ticks, :scale, :stroke, :name, :attrs
)
  ORIENTATIONS = { x: %i[top bottom], y: %i[left right] }.freeze
  TYPES = %i[category number auto].freeze
  NICE_TICKS = %i[auto adaptive snap125 none].freeze
  INTERVALS = %i[preserve_end preserve_start preserve_start_end equidistant_preserve_start equidistant_preserve_end].freeze
  SCALES = %i[auto linear].freeze

  class << self
    # The settings of a declared axis.
    #
    # @api private
    # @param kind [Symbol] :x or :y
    # @return [AxisSettings]
    # @raise [ArgumentError] on a value outside the supported ones
    def build(kind, **options)
      formatter = Chadcn::Chart::Cartesian::Formatter.resolve(options.delete(:tick_formatter))
      options[:orientation] = choice(:orientation, options[:orientation], ORIENTATIONS.fetch(kind))
      options[:type] = choice(:type, options[:type], TYPES)
      options[:nice_ticks] = choice(:nice_ticks, options[:nice_ticks], NICE_TICKS)
      options[:scale] = scale(options[:scale])
      options[:interval] = interval(options[:interval])
      options[:domain] = domain(options[:domain])
      options[:padding] = padding(kind, options[:padding])
      options[:id] = options.delete(:axis_id)
      new(kind: kind, tick_formatter: formatter, **options)
    end

    # The axis recharts uses when none is declared (`implicitXAxis` / `implicitYAxis`): hidden, with the default settings.
    #
    # @api private
    # @param kind [Symbol] :x or :y
    # @return [AxisSettings]
    def implicit(kind, id = 0)
      x = kind == :x
      new(kind: kind, id: id, data_key: nil, type: x ? :category : :number, hide: true, size: x ? 30 : 60, orientation: x ? :bottom : :left, tick: true,
          tick_line: true, axis_line: true, tick_size: 6, tick_margin: 2, tick_count: 5, tick_formatter: nil, interval: :preserve_end,
          min_tick_gap: 5, mirror: false, reversed: false, padding: x ? { left: 0, right: 0 } : { top: 0, bottom: 0 }, domain: nil,
          allow_decimals: true, allow_duplicated_category: true, allow_data_overflow: false, include_hidden: false, nice_ticks: :auto,
          angle: 0, unit: nil, ticks: nil, scale: :auto, stroke: "#666", name: nil, attrs: {})
    end

    private

    def choice(name, value, allowed)
      return value.to_sym if value.respond_to?(:to_sym) && allowed.include?(value.to_sym)

      raise ArgumentError, "#{name}: must be one of #{allowed.map(&:inspect).join(', ')} (got #{value.inspect})"
    end

    def scale(value)
      return value.to_sym if value.respond_to?(:to_sym) && SCALES.include?(value.to_sym)

      raise ArgumentError, "scale: #{value.inspect} is not ported (use :auto or :linear)"
    end

    def interval(value)
      return value if value.is_a?(Integer) && !value.negative?

      choice(:interval, value, INTERVALS)
    end

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

    def padding(kind, value)
      sides = kind == :x ? %i[left right] : %i[top bottom]
      return sides.to_h { |side| [ side, 0 ] } if value.nil?
      raise ArgumentError, "padding: must be a Hash of #{sides.join(' and ')} (got #{value.inspect})" unless value.is_a?(Hash)

      sides.to_h { |side| [ side, Chadcn::Chart::Cartesian::Value.number(value[side] || value[side.to_s]) || 0.0 ] }
    end
  end

  # @api private
  # @return [Boolean] whether the axis is the x axis
  def x? = kind == :x

  # @api private
  # @return [Boolean] whether the domain has `"auto"` as a bound (nice ticks may widen it)
  def auto_domain? = domain_definition.any?("auto")

  # recharts' `getDomainDefinition`: the domain, else the one the user ticks imply, else `[0, "auto"]`.
  #
  # @api private
  # @return [Array]
  def domain_definition
    return domain if domain

    numbers = ticks&.filter_map { |tick| Chadcn::Chart::Cartesian::Value.number(tick) }
    return [ numbers.min, numbers.max ] if type == :number && numbers&.any?

    [ 0, "auto" ]
  end
end

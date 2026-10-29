# frozen_string_literal: true

# One polar axis once the chart is laid out: its domain, scale and ticks, resolved the way recharts' polar selectors do
# (state/selectors/polarAxisSelectors.js, polarScaleSelectors.js, which share the domain and tick selectors of axisSelectors.js with the
# cartesian axes). The domain, the nice ticks and the scale are the cartesian axis resolution ({Chadcn::Chart::Cartesian::Axis}); what is
# polar here is the range (angles, or radii), the tick coordinates and which axis holds the categories.
#
# The angle axis holds the categories of a radar chart (layout `centric`) and the radius axis those of a radial bar chart (layout
# `radial`), `isCategoricalAxis` (util/ChartUtils.js:48).
#
# @api private
class Chadcn::Chart::Polar::Axis
  # A series as the axis resolution sees it: its data key only. A polar chart does not stack the domain (the polar numerical domain
  # takes `unsupportedInPolarChart` for the stacks, polarSelectors.js:34), so no item keeps its `stack_id` here.
  Item = Data.define(:options)

  private_constant :Item

  # @api private
  # @return [Chadcn::Chart::Polar::AxisSettings] the settings, with the `type` resolved
  attr_reader :settings

  # @api private
  # @param settings [Chadcn::Chart::Polar::AxisSettings]
  # @param layout [Symbol] :centric or :radial
  # @param rows [Array<Hash>] the data the axis reads
  # @param items [Array<#options>] the visible series on this axis
  # @param range [Array(Float, Float)] the angles, or the radii, the scale maps onto
  def initialize(settings, layout:, rows:, items:, range:)
    @categorical = layout == :centric ? settings.angle? : !settings.angle?
    type = resolved_type(settings)
    @settings = settings.with(type: type)
    @axis = Chadcn::Chart::Cartesian::Axis.new(
      settings.to_cartesian(type), layout: @categorical == settings.angle? ? :horizontal : :vertical, chart_type: :bar, rows: rows,
                                   items: items.map { |item| Item.new(options: { data_key: item.options[:data_key], hide: item.options[:hide] }) },
                                   stacks: Chadcn::Chart::Cartesian::Stacks.new([], []), references: [], range: range, stack_offset: :none
    )
    @ticks = settings.angle? ? unique_angles(@axis.ticks.map { |tick| angle_tick(tick) }) : @axis.ticks
    freeze
  end

  # @api private
  # @return [Boolean] whether this axis holds the categories of the chart (`isCategoricalAxis`)
  def categorical? = @categorical

  # @api private
  # @return [Boolean] whether the axis lists categories
  def category? = @axis.category?

  # @api private
  # @return [Boolean] whether the axis has a scale (data to draw)
  def scaled? = @axis.scaled?

  # @api private
  # @return [Array, nil] the domain after the nice ticks, nil when there is no data to draw
  def domain = @axis.domain

  # @api private
  # @return [Array(Float, Float)] the angles, or radii, of the scale (reversed for a reversed axis)
  def range = @axis.range

  # @api private
  # @return [Float, nil] the width of a category band (0 for a point scale), nil for a number axis
  def bandwidth = @axis.bandwidth

  # d3 `scale(value)` for a value of the domain.
  #
  # @api private
  # @param value [Object] a category, or a number
  # @return [Float, nil] nil for a value the scale does not know
  def position_of(value) = @axis.position_of(value)

  # `getBandSizeOfAxis` (util/ChartUtils.js:464).
  #
  # @api private
  # @param bar [Boolean] bars need a real width
  # @return [Float, nil]
  def band_size(bar: false) = @axis.band_size(bar: bar)

  # The ticks the axis draws (`selectPolarAxisTicks`, polarScaleSelectors.js:42): the nice ticks, or a tick per category, label centered on
  # its band; the angle axis shifts them by a whole band the way its direction asks (state/selectors/axisSelectors.js:1157), and lists an
  # angle once (`selectPolarAngleAxisTicks`, polarScaleSelectors.js:46).
  #
  # @api private
  # @return [Array<Chadcn::Chart::Cartesian::TickLayout::Tick>]
  attr_reader :ticks

  # The ticks series are positioned with (`selectPolarGraphicalItemAxisTicks`): the start of every band.
  #
  # @api private
  # @return [Array<Chadcn::Chart::Cartesian::TickLayout::Tick>]
  def item_ticks = @axis.item_ticks

  private

  # `getAxisTypeBasedOnLayout` (util/getAxisTypeBasedOnLayout.js): `auto` is a category axis where the chart holds the categories.
  def resolved_type(settings)
    return settings.type unless settings.type == :auto

    @categorical ? :category : :number
  end

  # The angle axis moves a tick by `sign(range[0] - range[1]) * 2 * offset`, where `offset` is half a band.
  def angle_tick(tick)
    return tick if tick.offset.zero?

    direction = Chadcn::Chart::Shape::JsMath.sign(range[0] - range[1])
    tick.with(coordinate: tick.coordinate - tick.offset + (direction * 2 * tick.offset), offset: direction * 2 * tick.offset)
  end

  def unique_angles(ticks) = ticks.uniq { |tick| (tick.coordinate + 360) % 360 }
end

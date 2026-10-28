# frozen_string_literal: true

# One axis once the chart is laid out: its domain, scale and ticks, resolved the way recharts' selectors do
# (state/selectors/axisSelectors.js). Built by {Chadcn::Chart::Cartesian::Layout}; the series and the renderer read it.
#
# The domain of a category axis is the list of categories (or the row indexes when there is no `data_key` or the categories repeat), the
# domain of a number axis is `[min, max]` (data, stacks, the user's `domain:` and the nice ticks, `domain_with_nice_ticks`).
#
# @api private
class Chadcn::Chart::Cartesian::Axis
  # `dataMin - 5` / `dataMax + 5` (util/ChartUtils.js MIN_VALUE_REG / MAX_VALUE_REG)
  MIN_OFFSET = /\AdataMin\s*-\s*(\d+(?:\.\d+)?)\z/
  MAX_OFFSET = /\AdataMax\s*\+\s*(\d+(?:\.\d+)?)\z/

  private_constant :MIN_OFFSET, :MAX_OFFSET

  # @api private
  # @return [Chadcn::Chart::Cartesian::AxisSettings] the settings, with the `type` resolved
  attr_reader :settings
  # @api private
  # @return [Array, nil] the domain after the nice ticks, nil when there is no data to draw
  attr_reader :domain
  # @api private
  # @return [Array<Float>, nil] the nice ticks of a number axis
  attr_reader :nice_ticks
  # @api private
  # @return [Symbol] :band, :point or :linear
  attr_reader :scale_type
  # @api private
  # @return [Array(Float, Float)] the pixel range of the scale (reversed for a reversed axis)
  attr_reader :range
  # @api private
  # @return [Boolean] whether this is the axis that holds the categories of the chart layout
  attr_reader :categorical

  # @api private
  # @param settings [Chadcn::Chart::Cartesian::AxisSettings]
  # @param layout [Symbol] :horizontal or :vertical
  # @param chart_type [Symbol] :bar, :line or :area
  # @param rows [Array<Hash>] the chart data
  # @param items [Array<#options>] the visible series on this axis
  # @param stacks [Chadcn::Chart::Cartesian::Stacks] the stacks of the series on this axis
  # @param references [Array<Hash>] the reference lines whose `if_overflow` extends the domain, as `{ x:, y: }` values
  # @param range [Array(Float, Float)] the pixel range the scale maps onto
  # @param stack_offset [Symbol] the chart's stack offset
  def initialize(settings, layout:, chart_type:, rows:, items:, stacks:, references:, range:, stack_offset:)
    @categorical = (layout == :horizontal) == settings.x?
    @settings = settings.type == :auto ? settings.with(type: auto_type) : settings
    @layout = layout
    @rows = rows
    @items = items
    @stacks = stacks
    @references = references
    @stack_offset = stack_offset
    @scale_type = scale_type_for(chart_type)
    @range = settings.reversed ? range.reverse : range
    resolve
    freeze
  end

  # @api private
  # @return [Boolean] whether the axis lists categories
  def category? = settings.type == :category

  # @api private
  # @return [Float, nil] the width of a band of a category axis (0 for a point scale), nil for a number axis
  def bandwidth = @scale.respond_to?(:bandwidth) ? @scale.bandwidth : nil

  # @api private
  # @return [Boolean] whether the axis has a scale (data to draw)
  def scaled? = !@scale.nil?

  # d3 `scale(value)` for a value of the domain.
  #
  # @api private
  # @param value [Object] a category, or a number
  # @return [Float, nil] nil for a value the scale does not know
  def position_of(value)
    return unless @scale

    if category?
      index = @category_index.fetch(value) { @categories.index(value) }
      index && @scale.call(index)
    else
      (number = Chadcn::Chart::Cartesian::Value.number(value)) && @scale.call(number)
    end
  end

  # The ticks the axis draws, before the collision pass (`selectTicksOfAxis`): a tick per nice tick / user tick / category, label
  # centered on its band.
  #
  # @api private
  # @return [Array<Chadcn::Chart::Cartesian::TickLayout::Tick>]
  attr_reader :ticks

  # The ticks series are positioned with (`selectTicksOfGraphicalItem`): the start of every band.
  #
  # @api private
  # @return [Array<Chadcn::Chart::Cartesian::TickLayout::Tick>]
  attr_reader :item_ticks

  # `getBandSizeOfAxis`: the width of a category band, else the smallest distance between two ticks.
  #
  # @api private
  # @param bar [Boolean] bars need a real width
  # @return [Float, nil]
  def band_size(bar: false)
    width = bandwidth
    return width if width && (!bar || width.positive?)

    if @item_ticks.size >= 2
      coordinates = @item_ticks.map(&:coordinate).sort
      return coordinates.each_cons(2).map { |left, right| right - left }.min
    end
    bar ? nil : 0.0
  end

  # @api private
  # @return [Array(Float, Float)] the smallest and largest value of the range, `rangeMin` and `rangeMax`
  def range_bounds = @range.minmax

  private

  def resolve
    @categories = []
    @category_index = {}
    numeric_domain = numerical_domain
    base = base_domain(numeric_domain)
    @nice_ticks = category? ? nil : nice_ticks_for(base)
    @domain = with_nice_ticks(base)
    @duplicates = duplicate_values
    @categories = category? && @domain ? @domain.uniq : []
    @category_index = @categories.each_with_index.to_h
    @scale = build_scale
    @ticks = scaled? ? axis_ticks(offset: true) : []
    @item_ticks = scaled? ? axis_ticks(offset: false) : []
  end

  def auto_type = @categorical ? :category : :number

  def scale_type_for(chart_type)
    return :linear unless category?

    %i[line area].include?(chart_type) ? :point : :band
  end

  # --- domain -------------------------------------------------------------------------------------------------------------

  # `combineAxisDomain`
  def base_domain(numeric_domain)
    return if @rows.empty? && numeric_domain.nil?
    return (0...@rows.size).to_a if @categorical && settings.data_key.nil?
    return category_domain if category?

    @stack_offset == :expand ? [ 0.0, 1.0 ] : numeric_domain
  end

  def applied_values
    if settings.data_key then @rows.map { |row| Chadcn::Chart::Cartesian::Value.read(row, settings.data_key) }
    elsif @items.any? then @items.flat_map { |item| @rows.map { |row| Chadcn::Chart::Cartesian::Value.read(row, item.options[:data_key]) } }
    else @rows
    end
  end

  # `computeDomainOfTypeCategory`
  def category_domain
    all = applied_values
    values = all.select { |value| value.is_a?(Numeric) || value.is_a?(String) }
    return (0...all.size).to_a if @categorical && (settings.data_key.nil? || (settings.allow_duplicated_category && duplicates?(values)))

    settings.allow_duplicated_category ? values : values.uniq
  end

  def duplicates?(values) = values.map(&:to_s).uniq.size != values.size

  # `combineDuplicateDomain`: the categories to show when the domain is the list of row indexes.
  def duplicate_values
    return unless settings.data_key && @categorical && category? && settings.allow_duplicated_category

    all = applied_values
    all if duplicates?(all)
  end

  # `combineNumericalDomain`
  def numerical_domain
    return if category?

    definition = settings.domain_definition
    preferred = domain_without_data(definition)
    return preferred if preferred

    value_axis = (@layout == :vertical) == settings.x?
    merged = merge_domains([ (@stacks.domain if value_axis), reference_domain, data_domain ])
    parse_user_domain(definition, merged)
  end

  # `numericalDomainSpecifiedWithoutRequiringData`: an explicit numeric domain with `allow_data_overflow`.
  def domain_without_data(definition)
    return unless settings.allow_data_overflow && definition.is_a?(Array)

    bounds = definition.map { |bound| bound.is_a?(Numeric) && bound.to_f.finite? ? bound.to_f : nil }
    bounds if bounds.none?(&:nil?)
  end

  def merge_domains(domains)
    present = domains.compact.flatten
    present.empty? ? nil : present.minmax
  end

  # `combineDomainOfAllAppliedNumericalValuesIncludingErrorValues` over the series that are not stacked.
  def data_domain
    low = high = nil
    extend_with = lambda do |value|
      range = value_domain(value) or next
      low = low.nil? ? range[0] : [ low, range[0] ].min
      high = high.nil? ? range[1] : [ high, range[1] ].max
    end
    unstacked = @items.reject { |item| item.options[:stack_id] }
    value_class = Chadcn::Chart::Cartesian::Value
    @rows.each { |row| unstacked.each { |item| extend_with.call(value_class.read(row, settings.data_key || item.options[:data_key])) } } if unstacked.any?
    @rows.each { |row| extend_with.call(value_class.read(row, settings.data_key)) } if settings.data_key
    [ low, high ] if low && high
  end

  # `makeDomain`: a number is a domain of one value, a pair is a range.
  def value_domain(value)
    if value.is_a?(Array)
      pair = [ Chadcn::Chart::Cartesian::Value.number(value[0]), Chadcn::Chart::Cartesian::Value.number(value[1]) ]
      return pair if pair.none?(&:nil?)

      return
    end
    number = Chadcn::Chart::Cartesian::Value.number(value)
    [ number, number ] if number
  end

  def reference_domain
    coordinates = @references.filter_map { |reference| Chadcn::Chart::Cartesian::Value.number(reference[settings.kind]) }
    coordinates.empty? ? nil : coordinates.minmax
  end

  # `parseNumericalUserDomain`
  def parse_user_domain(definition, data)
    return if !settings.allow_data_overflow && data.nil?

    if definition.respond_to?(:call)
      result = definition.call(data, settings.allow_data_overflow)
      return extend_domain(result, data) if well_formed?(result)
    end
    return unless definition.is_a?(Array) && definition.size == 2

    candidate = [ user_bound(definition[0], data, 0), user_bound(definition[1], data, 1) ]
    return unless well_formed?(candidate)

    data.nil? ? candidate : extend_domain(candidate, data)
  end

  def user_bound(bound, data, side)
    case bound
    when Numeric then bound.to_f
    when Proc, Method then data && bound.call(data[side])
    when String then user_offset_bound(bound, data, side)
    else data&.[](side)
    end
  end

  def user_offset_bound(bound, data, side)
    match = (side.zero? ? MIN_OFFSET : MAX_OFFSET).match(bound)
    return data&.[](side) unless match
    return unless data

    side.zero? ? data[0] - match[1].to_f : data[1] + match[1].to_f
  end

  def extend_domain(domain, data)
    settings.allow_data_overflow ? domain : [ [ domain[0], data[0] ].min, [ domain[1], data[1] ].max ]
  end

  def well_formed?(domain)
    domain.is_a?(Array) && domain.size == 2 && domain.all? { |bound| bound.is_a?(Numeric) && bound.to_f.finite? }
  end

  # `combineNiceTicks`
  def nice_ticks_for(domain)
    mode = settings.nice_ticks
    count = settings.tick_count
    return if mode == :none || !count&.nonzero? || !well_formed?(domain)

    step_mode = mode == :snap125 ? :snap125 : :auto
    forced = %i[snap125 adaptive].include?(mode)
    return unless forced || (mode == :auto && @scale_type == :linear)

    if settings.auto_domain?
      Chadcn::Chart::Scale::NiceTicks.values(*domain, count, allow_decimals: settings.allow_decimals, mode: step_mode)
    elsif settings.type == :number
      Chadcn::Chart::Scale::NiceTicks.fixed_domain(*domain, count, allow_decimals: settings.allow_decimals, mode: step_mode)
    end
  end

  # `combineAxisDomainWithNiceTicks`
  def with_nice_ticks(domain)
    return domain unless settings.type == :number && well_formed?(domain) && @nice_ticks&.any?

    [ [ domain[0], @nice_ticks.first ].min, [ domain[1], @nice_ticks.last ].max ]
  end

  # --- scale and ticks ----------------------------------------------------------------------------------------------------

  def build_scale
    return unless @domain && @range

    if category?
      return if @categories.empty?

      kind = @scale_type == :point ? Chadcn::Chart::Scale::Point : Chadcn::Chart::Scale::Band
      kind.new(count: @categories.size, range: @range)
    elsif well_formed?(@domain)
      Chadcn::Chart::Scale::Linear.new(domain: @domain, range: @range)
    end
  end

  # `combineAxisTicks` (`offset: true`, labels centered on their band) and `combineGraphicalItemTicks` (`offset: false`).
  def axis_ticks(offset:)
    shift = offset && category? && bandwidth ? bandwidth / 2 : 0.0
    source = offset ? (settings.ticks || @nice_ticks) : nil
    entries = if source
      source.each_with_index.map { |value, index| [ index, value, position_of(@duplicates ? @duplicates.index(value) : value) ] }
    elsif !category? && @scale.respond_to?(:ticks)
      @scale.ticks(settings.tick_count).each_with_index.map { |value, index| [ index, value, @scale.call(value) ] }
    else
      (category? ? @categories : []).each_with_index.map { |entry, index| [ index, @duplicates ? @duplicates[entry] : entry, position_of(entry) ] }
    end
    entries.filter_map do |index, value, scaled|
      Chadcn::Chart::Cartesian::TickLayout::Tick.new(index: index, value: value, coordinate: scaled + shift, offset: shift) if scaled&.finite?
    end
  end
end

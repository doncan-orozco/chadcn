# frozen_string_literal: true

# The stack groups of one value axis: the stacked bars and areas that share a stack id are stacked on each other
# (recharts `combineStackGroups`, state/selectors/axisSelectors.js:432-462) with the d3 stack of {Chadcn::Chart::Shape::Stack}, and
# the domain they cover (`getDomainOfStackGroups`, util/ChartUtils.js:431).
#
# @api private
class Chadcn::Chart::Cartesian::Stacks
  Value = Chadcn::Chart::Cartesian::Value

  private_constant :Value

  # @api private
  # @param rows [Array<Hash>] the chart data
  # @param items [Array<#options>] the series on the axis that have a `stack_id` (bars and areas)
  # @param offset [Symbol] :none or :expand
  # @param reverse [Boolean] stack the series in reverse order of declaration
  def initialize(rows, items, offset: :none, reverse: false)
    @pairs = {}
    Chadcn::Chart::Shape::Stack::Groups.by_id(items) { |item| item.options[:stack_id] }.each do |group|
      ordered = reverse ? group.reverse : group
      stacked = Chadcn::Chart::Shape::Stack.series(rows, ordered, offset: offset) do |row, item|
        value = Value.read(row, item.options[:data_key])
        value.is_a?(Array) ? value : (Value.number(value) || 0.0)
      end
      ordered.each_with_index { |item, index| @pairs[item] = stacked[index] }
    end
    freeze
  end

  # The `[lower, upper]` pair of every row for a stacked series.
  #
  # @api private
  # @param item [#options]
  # @return [Array<Array(Float, Float)>, nil] nil for a series that is not stacked
  def pairs(item) = @pairs[item]

  # @api private
  # @return [Array(Float, Float), nil] the lowest and highest value of every stack, nil when nothing is stacked or the stacks span only 0
  def domain
    values = @pairs.values.flatten.select { |value| value.is_a?(Numeric) && !value.nan? }
    return if values.empty?

    low = values.min
    high = values.max
    low = 0.0 if low == Float::INFINITY
    high = 0.0 if high == -Float::INFINITY
    [ low, high ] unless low.zero? && high.zero?
  end
end

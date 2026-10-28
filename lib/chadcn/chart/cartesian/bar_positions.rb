# frozen_string_literal: true

# How wide a bar is and where it sits inside its category band: recharts' `combineBarSizeList` and `combineAllBarPositions`
# (state/selectors/combiners/*.js). One slot per stack (the bars that share a `stack_id`) and one per bar without one, in that order.
#
# @api private
module Chadcn::Chart::Cartesian::BarPositions
  # A slot: the stack id (nil for a bar alone), the data keys it holds and the `bar_size` its first bar asked for.
  Slot = Data.define(:stack_id, :data_keys, :bar_size)
  # Where a slot sits: `offset` from the start of the band, `size` of the bar.
  Position = Data.define(:stack_id, :data_keys, :offset, :size)

  JS_INDEX = /\A(?:0|[1-9]\d*)\z/

  private_constant :JS_INDEX

  class << self
    # `combineBarSizeList`.
    #
    # @api private
    # @param bars [Array<#options>] the visible bars on the category axis
    # @param global_size [Numeric, String, nil] the chart's `bar_size`
    # @param total_size [Float] the length of the category axis
    # @return [Array<Slot>]
    def slots(bars, global_size, total_size)
      stacked, alone = bars.partition { |bar| bar.options[:stack_id] }
      groups = stacked.group_by { |bar| bar.options[:stack_id].to_s }
      # JavaScript object keys: integer-like ids first, ascending, then the others in order of insertion
      ordered = groups.keys.partition { |id| JS_INDEX.match?(id) }.then { |numbers, others| numbers.sort_by(&:to_i) + others }
      stacks = ordered.map do |id|
        Slot.new(stack_id: id, data_keys: groups[id].map { |bar| bar.options[:data_key] },
                 bar_size: bar_size(global_size, total_size, groups[id].first.options[:bar_size]))
      end
      stacks +
        alone.map do |bar|
          Slot.new(stack_id: nil, data_keys: [ bar.options[:data_key] ].compact, bar_size: bar_size(global_size, total_size, bar.options[:bar_size]))
        end
    end

    # `combineAllBarPositions` (and `getBarPositions`).
    #
    # @api private
    # @param slots [Array<Slot>]
    # @param global_max [Numeric, nil] the chart's `max_bar_size`
    # @param bar_gap [Numeric, String] the chart's `bar_gap`
    # @param category_gap [Numeric, String] the chart's `bar_category_gap`
    # @param bar_band [Float] the band the bars are laid out in (`getBandSizeOfAxis(..., isBar)`)
    # @param band [Float] the band size of the axis
    # @param child_max [Numeric, nil] the `max_bar_size` of the bar being positioned
    # @return [Array<Position>, nil]
    def positions(slots, global_max:, bar_gap:, category_gap:, bar_band:, band:, child_max:)
      max = child_max.nil? ? global_max : child_max
      result = layout(bar_gap, category_gap, bar_band, slots, max)
      return result if result.nil? || bar_band == band

      result.map { |position| position.with(offset: position.offset - (bar_band / 2)) }
    end

    # `combineBarPosition`: the position of the slot a bar belongs to.
    #
    # @api private
    # @param positions [Array<Position>, nil]
    # @param bar [#options]
    # @return [Position, nil]
    def position_for(positions, bar)
      key = bar.options[:data_key]
      stack_id = bar.options[:stack_id]&.to_s
      positions&.find { |position| position.stack_id == stack_id && !key.nil? && position.data_keys.include?(key) }
    end

    private

    # `getBarSize`
    def bar_size(global_size, total_size, own)
      size = own.nil? ? global_size : own
      size.nil? ? nil : Chadcn::Chart::Cartesian::Value.percent(size, total_size, 0.0)
    end

    def layout(bar_gap, category_gap, band, slots, max)
      return if slots.empty?

      gap = Chadcn::Chart::Cartesian::Value.percent(bar_gap, band, 0.0, validate: true)
      if slots.first.bar_size.is_a?(Numeric) && slots.first.bar_size.to_f.finite?
        sized(slots, band, gap)
      else
        equal(slots, band, gap, Chadcn::Chart::Cartesian::Value.percent(category_gap, band, 0.0, validate: true), max)
      end
    end

    # The first stack asked for a `bar_size`: the group is centered.
    def sized(slots, band, gap)
      count = slots.size
      full = band / count
      sum = slots.sum { |slot| slot.bar_size || 0 } + ((count - 1) * gap)
      if sum >= band
        sum -= (count - 1) * gap
        gap = 0.0
      end
      use_full = false
      if sum >= band && full.positive?
        use_full = true
        full *= 0.9
        sum = count * full
      end
      previous = (((band - sum) / 2).to_i - gap).to_f
      previous_size = 0.0
      slots.map do |slot|
        offset = previous + previous_size + gap
        size = use_full ? full : (slot.bar_size || 0)
        previous = offset
        previous_size = size
        Position.new(stack_id: slot.stack_id, data_keys: slot.data_keys, offset: offset, size: size)
      end
    end

    # No `bar_size`: the band minus the category gap is shared equally.
    def equal(slots, band, gap, offset, max)
      count = slots.size
      gap = 0.0 if band - (2 * offset) - ((count - 1) * gap) <= 0
      original = (band - (2 * offset) - ((count - 1) * gap)) / count
      original = original.to_i.to_f if original > 1
      size = max.is_a?(Numeric) && max.to_f.finite? ? [ original, max ].min : original
      slots.each_with_index.map do |slot, index|
        Position.new(stack_id: slot.stack_id, data_keys: slot.data_keys, offset: offset + ((original + gap) * index) + ((original - size) / 2), size: size)
      end
    end
  end
end

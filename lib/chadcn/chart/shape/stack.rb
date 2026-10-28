# frozen_string_literal: true

# d3-shape `stack()` as recharts drives it (util/ChartUtils.js `getStackedData`): series order is the key order, a missing or nil
# value counts as 0, and the offsets are `:none` (plain stacking) and `:expand` (every column normalized to 1). Which items share a
# stack is {Chadcn::Chart::Shape::Stack::Groups}.
#
# @api private
module Chadcn::Chart::Shape::Stack
  # Offsets supported by {.series}.
  OFFSETS = %i[none expand].freeze

  private_constant :OFFSETS

  class << self
    # One series per key, each a list of `[lower, upper]` pairs, one per data row.
    #
    # A value that is a two-number array is taken as a ready-made `[lower, upper]` range and left out of the stacking, like recharts.
    #
    # @api private
    # @param data [Array<Hash>] rows
    # @param keys [Array<Object>] hash keys of the series, bottom to top
    # @param offset [Symbol, String] :none or :expand
    # @yieldparam row [Hash]
    # @yieldparam key [Object]
    # @yieldreturn [Numeric, Array, nil] custom value reader; defaults to `row[key]`
    # @return [Array<Array<Array(Float, Float)>>]
    # @raise [ArgumentError] on an unknown offset
    def series(data, keys, offset: :none, &reader)
      mode = offset.to_sym
      raise ArgumentError, "unknown stack offset #{offset.inspect}, expected one of #{OFFSETS.join(', ')}" unless OFFSETS.include?(mode)

      reader ||= ->(row, key) { row[key] }
      raw = data.map { |row| keys.map { |key| reader.call(row, key) } }
      stacked = keys.each_index.map { |series_index| raw.map { |values| [ 0.0, numeric_or_zero(values[series_index]) ] } }
      # The three steps edit the pairs in place and the order matters: expand scales the plain values, stacking then lifts each pair onto
      # the one below, and the ready-made ranges overwrite whatever the first two produced.
      normalize_columns(stacked) if mode == :expand
      stack_up(stacked)
      stacked.each_with_index do |series_pairs, series_index|
        series_pairs.each_with_index { |pair, row_index| overwrite_with_range(pair, raw[row_index][series_index]) }
      end
      stacked
    end

    private

    # `Number(value)` for the values of a chart: nil and non-numbers are 0.
    def numeric_or_zero(value)
      value.is_a?(Numeric) ? value.to_f : 0.0
    end

    # d3 offset "expand": divide every upper value by the column total (columns that total 0 or NaN stay as they are). Edits the pairs
    # in place.
    def normalize_columns(stacked)
      return if stacked.empty?

      stacked.first.each_index do |row_index|
        total = stacked.sum(0.0) { |series_pairs| series_pairs[row_index][1].nan? ? 0.0 : series_pairs[row_index][1] }
        stacked.each { |series_pairs| series_pairs[row_index][1] /= total } unless total.zero? || total.nan?
      end
    end

    # d3 offset "none": every series sits on top of the previous one. Edits the pairs of the upper series in place, bottom to top, so
    # each one reads the already lifted pair below it.
    def stack_up(stacked)
      stacked.each_cons(2) do |below, above|
        above.each_with_index do |pair, row_index|
          pair[0] = below[row_index][1].nan? ? below[row_index][0] : below[row_index][1]
          pair[1] += pair[0]
        end
      end
    end

    # A value that is a two-number array is a ready-made `[lower, upper]` range and replaces the stacked pair (in place).
    def overwrite_with_range(pair, value)
      return unless value.is_a?(Array) && value.size == 2 && value.all?(Numeric)

      pair[0] = value[0].to_f
      pair[1] = value[1].to_f
    end
  end
end

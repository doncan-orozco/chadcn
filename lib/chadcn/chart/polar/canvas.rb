# frozen_string_literal: true

# What every drawer of a polar chart's svg shares: the laid-out chart, the prefix of the ids the chart writes, the tooltip entry that
# `default_index:` shows, the series whose shapes are tooltip items (`shared: false` on a radial bar chart, series => position) and the
# next number for the ids a drawer makes up (`recharts-radial-line-<n>`).
#
# @api private
Chadcn::Chart::Polar::Canvas = Data.define(:layout, :uid, :tooltip_entry, :counter, :tooltip_items) do
  def initialize(layout:, uid:, tooltip_entry:, counter:, tooltip_items: {}) = super

  # The next id of a kind, unique in the chart (recharts' `uniqueId`, util/DataUtils.js).
  #
  # @api private
  # @param prefix [String]
  # @return [String]
  def next_id(prefix) = "#{prefix}#{uid}-#{counter.next}"
end

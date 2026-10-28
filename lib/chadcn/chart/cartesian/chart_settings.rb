# frozen_string_literal: true

# What a cartesian chart tells its layout pass about itself (the options of `Chart::BarChart`, `LineChart` and `AreaChart` plus the size
# it is laid out at). Every member is required, so a missing one fails when the settings are built.
#
# @api private
Chadcn::Chart::Cartesian::ChartSettings = Data.define(
  :type, :direction, :width, :height, :margin, :rows, :text, :bar_category_gap, :bar_gap, :bar_size, :max_bar_size, :stack_offset,
  :reverse_stack_order, :base_value
)

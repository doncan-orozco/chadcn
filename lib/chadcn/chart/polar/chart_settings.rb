# frozen_string_literal: true

# What a polar chart tells its layout pass about itself (the options of `Chart::PieChart`, `RadarChart` and `RadialBarChart` plus the
# size it is laid out at). Every member is required, so a missing one fails when the settings are built.
#
# @api private
Chadcn::Chart::Polar::ChartSettings = Data.define(
  :type, :layout, :width, :height, :margin, :rows, :text, :cx, :cy, :inner_radius, :outer_radius, :start_angle, :end_angle,
  :bar_category_gap, :bar_gap, :bar_size, :max_bar_size
)

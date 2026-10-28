# frozen_string_literal: true

require "json"

# The inert `<template>` of every tooltip index (dev/port/specs/chart.md, "Tooltip"): the content for that category's payload, plus the
# data `chadcn--chart` needs to show it (the index, the label, where it anchors, the cursor and the active dots). Written as children of
# the chart's container, after the responsive shell.
#
# @api private
class Chadcn::Chart::Cartesian::TooltipTemplates < Chadcn::Base
  TARGET = "tooltipTemplate"

  private_constant :TARGET

  # @api private
  # @param plan [Chadcn::Chart::Cartesian::TooltipPlan]
  def initialize(plan:)
    @plan = plan
    super()
  end

  # @return [void]
  def view_template
    return unless @plan.tooltip.content_element

    @plan.entries.each do |entry|
      template(**attributes(entry)) { render @plan.content(entry) }
    end
  end

  private

  def attributes(entry)
    cursor = entry.cursor
    { "data-chadcn--chart-target": TARGET, "data-index": entry.index.to_s, "data-label": entry.label.to_s,
      "data-coordinate": JSON.generate(entry.coordinate.transform_values { |value| whole(value) }),
      "data-cursor": (JSON.generate(tag: "path", attrs: cursor[:attrs]) if cursor),
      "data-active-dots": JSON.generate(entry.dots.map { |dot| dot[:attrs] }) }
  end

  # A pixel that is a whole number is written as one (`5`, not `5.0`).
  def whole(value) = value == value.to_i ? value.to_i : value
end

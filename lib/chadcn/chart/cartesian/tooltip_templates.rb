# frozen_string_literal: true

require "json"

# The inert `<template>` of every tooltip index (dev/port/specs/chart.md, "Tooltip"): the content for that category's payload, plus the
# data `chadcn--chart` needs to show it (the index, the label, where it anchors, the cursor, the active dots and the payload the activate
# event carries). Written as children of the chart's container, after the responsive shell.
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

  # An item entry (`shared: false`, a pie) carries its series and, when its shape has one, where the pointer on it places the tooltip; it has
  # no label (recharts passes none to an item tooltip, component/Tooltip.js:131). A polar category carries the cursor its pointer draws.
  def attributes(entry)
    cursor = entry.cursor
    pointer_cursor = entry.pointer_cursor
    { "data-chadcn--chart-target": TARGET, "data-index": entry.index.to_s, "data-label": (entry.label.to_s unless entry.item?),
      "data-series": (entry.series.to_s if entry.item?), "data-coordinate": point(entry.coordinate),
      "data-item-coordinate": (point(entry.item_coordinate) if entry.item_coordinate),
      "data-cursor": (JSON.generate(tag: "path", layer: cursor.layer, attrs: cursor.attrs) if cursor),
      "data-pointer-cursor": (JSON.generate(tag: "path", layer: pointer_cursor.layer, attrs: pointer_cursor.attrs) if pointer_cursor),
      "data-active-dots": JSON.generate(entry.dots.map(&:attrs)), "data-payload": JSON.generate(entry.payload.map { |item| detail(item) }) }
  end

  def point(coordinate) = JSON.generate(coordinate.transform_values { |value| whole(value) })

  # What `chadcn--chart:activate` hands to a host: the series at this category, without the data row.
  def detail(item)
    { name: item[:name], dataKey: item[:data_key], value: item[:value], color: item[:color], type: item[:type], unit: item[:unit] }.compact
  end

  # A pixel that is a whole number is written as one (`5`, not `5.0`).
  def whole(value) = value == value.to_i ? value.to_i : value
end

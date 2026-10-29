# frozen_string_literal: true

require_relative "../cartesian/chart_helper"

# What the polar chart tests share: the browser rows of the shadcn pie examples, the rows of the radar and radial bar examples
# (ChartHelper::ROWS) and renders of the three charts inside a container.
module PolarHelper
  include ChartHelper

  BROWSERS = [
    { browser: "chrome", visitors: 275, fill: "var(--color-chrome)" },
    { browser: "safari", visitors: 200, fill: "var(--color-safari)" },
    { browser: "firefox", visitors: 187, fill: "var(--color-firefox)" },
    { browser: "edge", visitors: 173, fill: "var(--color-edge)" },
    { browser: "other", visitors: 90, fill: "var(--color-other)" }
  ].freeze
  BROWSER_CONFIG = {
    visitors: { label: "Visitors" }, chrome: { label: "Chrome", color: "var(--chart-1)" }, safari: { label: "Safari", color: "var(--chart-2)" },
    firefox: { label: "Firefox", color: "var(--chart-3)" }, edge: { label: "Edge", color: "var(--chart-4)" }, other: { label: "Other", color: "var(--chart-5)" }
  }.freeze

  # A pie of the browsers in a container; the block receives the pie, `around` the chart (to declare a tooltip or a legend before the pie).
  def render_pie(chart: {}, container: {}, around: nil, **pie, &block)
    render_chart(Chadcn::Chart::PieChart, container: { config: BROWSER_CONFIG }.merge(container), data: [], **chart) do |inner|
      around&.call(inner)
      inner.pie(data: BROWSERS, data_key: :visitors, name_key: :browser, **pie, &block)
    end
  end

  # The sector paths of the nth pie of a parsed chart.
  def sectors(doc, index = 0) = doc.css("g.recharts-pie")[index].css("path.recharts-sector")

  # A radar chart of the months in a container; the block receives the chart.
  def render_radar(chart: {}, container: {}, &)
    render_chart(Chadcn::Chart::RadarChart, container: container, **chart, &)
  end

  # A radial bar chart of the browsers in a container; the block receives the chart.
  def render_radial_bar(chart: {}, container: {}, &)
    props = { data: BROWSERS.first(3), inner_radius: 30, outer_radius: 100 }.merge(chart)
    render_chart(Chadcn::Chart::RadialBarChart, container: { config: BROWSER_CONFIG }.merge(container), **props, &)
  end

  # The arcs of the nth radial bar of a parsed chart (the layer-300 group `recharts-area`).
  def arcs(doc, index = 0) = layer(doc, 300).css("> g.recharts-area")[index].css("path.recharts-radial-bar-sector")
end

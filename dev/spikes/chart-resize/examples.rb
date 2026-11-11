# frozen_string_literal: true

# The two examples of ../chart/examples.tsx (stacked bar with grid, x axis, legend and a default-index tooltip; monotone line with dots and a
# y axis), written with the gem, laid out at any size: `ResizeSpike::Examples.render(:bar, width: 560, height: 315)`.
require "chadcn"

module ResizeSpike
  module Examples
    MONTHS = %w[January February March April May June].freeze
    BAR_ROWS = MONTHS.zip([ 186, 305, 237, 73, 209, 214 ], [ 80, 200, 120, 190, 130, 140 ]).map { |m, d, mo| { month: m, desktop: d, mobile: mo } }.freeze
    LINE_ROWS = BAR_ROWS.map { |row| row.slice(:month, :desktop) }.freeze
    BAR_CONFIG = { desktop: { label: "Desktop", color: "var(--chart-1)" }, mobile: { label: "Mobile", color: "var(--chart-2)" } }.freeze
    LINE_CONFIG = { desktop: { label: "Desktop", color: "var(--chart-1)" } }.freeze
    NAMES = %i[bar line].freeze

    # A host page that draws one example inside its container.
    class Page < Phlex::HTML
      def initialize(name, width:, height:, **metrics)
        @name = name
        @dimension = { width: width, height: height }
        @legend_height = metrics.delete(:legend_height) || 28
        @metrics = metrics
      end

      def view_template = send(@name)

      private

      def bar
        render Chadcn::Chart::Container.new(config: BAR_CONFIG, id: "spike-bar", initial_dimension: @dimension, **@metrics) do
          render Chadcn::Chart::BarChart.new(data: BAR_ROWS) do |chart|
            chart.cartesian_grid(vertical: false)
            chart.x_axis(data_key: :month, tick_line: false, tick_margin: 10, axis_line: false, tick_formatter: { slice: [ 0, 3 ] })
            chart.tooltip(default_index: 1, content: Chadcn::Chart::Tooltip::Content.new(hide_label: true))
            chart.legend(content: Chadcn::Chart::Legend::Content.new, legend_height: @legend_height)
            chart.bar(data_key: :desktop, stack_id: "a", fill: "var(--color-desktop)", radius: [ 0, 0, 4, 4 ])
            chart.bar(data_key: :mobile, stack_id: "a", fill: "var(--color-mobile)", radius: [ 4, 4, 0, 0 ])
          end
        end
      end

      def line
        render Chadcn::Chart::Container.new(config: LINE_CONFIG, id: "spike-line", initial_dimension: @dimension, **@metrics) do
          render Chadcn::Chart::LineChart.new(data: LINE_ROWS, margin: { left: 12, right: 12 }) do |chart|
            chart.cartesian_grid(vertical: false)
            chart.x_axis(data_key: :month, tick_line: false, axis_line: false, tick_margin: 8, tick_formatter: { slice: [ 0, 3 ] })
            chart.y_axis(tick_line: false, axis_line: false, tick_margin: 8)
            chart.tooltip(cursor: false, content: Chadcn::Chart::Tooltip::Content.new(hide_label: true))
            chart.line(data_key: :desktop, type: :monotone, stroke: "var(--color-desktop)", stroke_width: 2, dot: true)
          end
        end
      end
    end

    # @param metrics [Hash] `text_height:` and `text_char_width:` of the container and `legend_height:` of the legend (the defaults when absent)
    def self.render(name, width:, height:, **metrics) = Page.new(name, width: width, height: height, **metrics).call
  end
end

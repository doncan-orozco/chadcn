# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::DeclarationsTest < Chadcn::TestCase
  include ChartHelper

  test "each helper renders the same HTML as the explicit class" do
    helpers = render_chart do |chart|
      chart.cartesian_grid(vertical: false)
      chart.x_axis(data_key: :month, tick_formatter: SLICE)
      chart.bar(data_key: :desktop, fill: "red") do |bar|
        bar.label_list(position: :top)
        bar.cell(fill: "blue")
      end
    end
    explicit = render_chart do |chart|
      chart.render Chadcn::Chart::CartesianGrid.new(vertical: false)
      chart.render Chadcn::Chart::XAxis.new(data_key: :month, tick_formatter: SLICE)
      chart.render(Chadcn::Chart::Bar.new(data_key: :desktop, fill: "red")) do |bar|
        bar.render Chadcn::Chart::LabelList.new(position: :top)
        bar.render Chadcn::Chart::Cell.new(fill: "blue")
      end
    end

    assert_equal explicit, helpers
  end

  test "the tooltip and legend helpers register the element and render it" do
    seen = nil
    render_chart do |chart|
      chart.tooltip(default_index: 1)
      chart.legend(vertical_align: :top)
      seen = chart
    end

    assert_respond_to seen, :tooltip
    assert_respond_to seen, :legend
  end

  test "tooltip and legend outside a chart raise" do
    outside = Class.new(Phlex::HTML) do
      include Chadcn::Chart::Declarations

      def view_template = tooltip
    end

    assert_raises(ArgumentError) { outside.new.call }
  end

  test "every chart class and every series includes the module" do
    chart = Chadcn::Chart

    [ chart::BarChart, chart::LineChart, chart::AreaChart, chart::Bar, chart::Line, chart::Area ].each do |klass|
      assert_includes klass.ancestors, Chadcn::Chart::Declarations
    end
  end
end

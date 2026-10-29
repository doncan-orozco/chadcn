# frozen_string_literal: true

require_relative "polar_helper"

class Chadcn::Chart::Polar::DeclarationsTest < Chadcn::TestCase
  include PolarHelper

  C = Chadcn::Chart

  test "the pie helper and the helpers inside a pie render the same HTML as the explicit classes" do
    helpers = render_chart(C::PieChart, container: { config: BROWSER_CONFIG }, data: []) do |chart|
      chart.pie(data: BROWSERS, data_key: :visitors, name_key: :browser) do |pie|
        pie.cell(fill: "blue")
        pie.label_list(data_key: :visitors, position: :outside)
        pie.label(value: "Total", position: :center)
      end
    end
    explicit = render_chart(C::PieChart, container: { config: BROWSER_CONFIG }, data: []) do |chart|
      chart.render(C::Pie.new(data: BROWSERS, data_key: :visitors, name_key: :browser)) do |pie|
        pie.render C::Cell.new(fill: "blue")
        pie.render C::LabelList.new(data_key: :visitors, position: :outside)
        pie.render C::Label.new(value: "Total", position: :center)
      end
    end

    assert_equal explicit, helpers
    assert_includes helpers, "recharts-pie"
  end

  test "the radar, polar grid and polar axis helpers render the same HTML as the explicit classes" do
    helpers = render_radar do |chart|
      chart.polar_angle_axis(data_key: :month)
      chart.polar_radius_axis(angle: 90)
      chart.polar_grid(grid_type: :circle)
      chart.radar(data_key: :desktop, fill: "red")
    end
    explicit = render_radar do |chart|
      chart.render C::PolarAngleAxis.new(data_key: :month)
      chart.render C::PolarRadiusAxis.new(angle: 90)
      chart.render C::PolarGrid.new(grid_type: :circle)
      chart.render C::Radar.new(data_key: :desktop, fill: "red")
    end

    assert_equal explicit, helpers
    assert_includes helpers, "recharts-radar"
  end

  test "the radial bar helper renders the same HTML as the explicit class" do
    helpers = render_radial_bar { |chart| chart.radial_bar(data_key: :visitors, background: true) }
    explicit = render_radial_bar { |chart| chart.render C::RadialBar.new(data_key: :visitors, background: true) }

    assert_equal explicit, helpers
    assert_includes helpers, "recharts-radial-bar-sector"
  end

  test "the root helpers pie_chart, radar_chart and radial_bar_chart render the same HTML as the explicit charts" do
    pie_helper = Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render(C.new) { |chart| chart.pie_chart(data: []) { |c| c.pie(data: BROWSERS, data_key: :visitors) } }
      end
    end.new.call
    pie_explicit = Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render(C::PieChart.new(data: [])) { |c| c.render C::Pie.new(data: BROWSERS, data_key: :visitors) }
      end
    end.new.call
    radar_helper = Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render(C.new) { |chart| chart.radar_chart(data: ROWS) { |c| c.radar(data_key: :desktop) } }
      end
    end.new.call
    radar_explicit = Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render(C::RadarChart.new(data: ROWS)) { |c| c.render C::Radar.new(data_key: :desktop) }
      end
    end.new.call

    radial_helper = Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render(C.new) { |chart| chart.radial_bar_chart(data: BROWSERS.first(3), inner_radius: 30) { |c| c.radial_bar(data_key: :visitors) } }
      end
    end.new.call
    radial_explicit = Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render(C::RadialBarChart.new(data: BROWSERS.first(3), inner_radius: 30)) { |c| c.render C::RadialBar.new(data_key: :visitors) }
      end
    end.new.call

    assert_equal pie_explicit, pie_helper
    assert_equal radial_explicit, radial_helper
    assert_equal radar_explicit, radar_helper
  end
end

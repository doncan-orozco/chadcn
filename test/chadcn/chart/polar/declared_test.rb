# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Polar::DeclaredTest < Chadcn::TestCase
  def declared(chart = Chadcn::Chart::RadarChart) = Chadcn::Chart::Polar::Declared.new(chart: chart)

  test "keeps what was declared in order, split by kind" do
    list = declared
    parts = [ Chadcn::Chart::PolarGrid.new, Chadcn::Chart::PolarAngleAxis.new(angle_axis_id: "a"), Chadcn::Chart::Radar.new(data_key: :a),
              Chadcn::Chart::PolarRadiusAxis.new, Chadcn::Chart::Label.new(value: "x") ]
    parts.each { |part| list.declare(part) }

    assert_equal parts, list.items
    assert_equal [ "a" ], list.angle_axes.map(&:id)
    assert_equal [ 0 ], list.radius_axes.map(&:id)
    assert_equal [ parts[2] ], list.series
    assert_equal [ parts[0] ], list.of(Chadcn::Chart::PolarGrid)
  end

  test "tooltip and legend are kept for the overlays, and a second one is refused" do
    list = declared(Chadcn::Chart::PieChart)
    tooltip = Chadcn::Chart::Tooltip.new
    list.declare(tooltip)
    list.declare(legend = Chadcn::Chart::Legend.new)

    assert_same tooltip, list.tooltip
    assert_same legend, list.legend
    assert_equal "a chart takes one tooltip (got a second Chadcn::Chart::Tooltip)", assert_raises(ArgumentError) { list.declare(Chadcn::Chart::Tooltip.new) }.message
    assert_equal "a chart takes one legend (got a second Chadcn::Chart::Legend)", assert_raises(ArgumentError) { list.declare(Chadcn::Chart::Legend.new) }.message
  end

  test "a chart holds the series of its own kind only" do
    pie = assert_raises(ArgumentError) { declared(Chadcn::Chart::PieChart).declare(Chadcn::Chart::Radar.new(data_key: :a)) }
    radar = assert_raises(ArgumentError) { declared(Chadcn::Chart::RadarChart).declare(Chadcn::Chart::Pie.new) }

    assert_equal "Chadcn::Chart::Radar does not go in a Chadcn::Chart::PieChart (it holds a Chart::Pie)", pie.message
    assert_equal "Chadcn::Chart::Pie does not go in a Chadcn::Chart::RadarChart (it holds a Chart::Radar)", radar.message
  end

  test "a pie chart has no polar axes" do
    error = assert_raises(ArgumentError) { declared(Chadcn::Chart::PieChart).declare(Chadcn::Chart::PolarAngleAxis.new) }

    assert_match(/has no polar axes/, error.message)
  end

  test "a part that goes in a series does not go directly in a chart" do
    error = assert_raises(ArgumentError) { declared.declare(Chadcn::Chart::Cell.new) }

    assert_match(/does not go directly in a Chadcn::Chart::RadarChart/, error.message)
    assert_raises(ArgumentError) { declared.declare(Chadcn::Chart::LabelList.new) }
    assert_raises(ArgumentError) { declared.declare(Chadcn::Chart::XAxis.new) }
  end
end

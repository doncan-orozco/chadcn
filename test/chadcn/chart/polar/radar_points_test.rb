# frozen_string_literal: true

require_relative "polar_helper"

class Chadcn::Chart::Polar::RadarPointsTest < Chadcn::TestCase
  include PolarHelper

  Settings = Chadcn::Chart::Polar::AxisSettings
  VIEW_BOX = Chadcn::Chart::Polar::ViewBox.new(cx: 160, cy: 100, inner_radius: 0, outer_radius: 76, start_angle: 90, end_angle: -270)

  def points(rows: ROWS, angle_key: :month, series: Chadcn::Chart::Radar.new(data_key: :desktop))
    settings = Settings.implicit(:angle).with(data_key: angle_key)
    angle = Chadcn::Chart::Polar::Axis.new(settings, layout: :centric, rows: rows, items: [ series ], range: [ 90.0, -270.0 ])
    radius = Chadcn::Chart::Polar::Axis.new(Settings.implicit(:radius), layout: :centric, rows: rows, items: [ series ], range: [ 0.0, 76.0 ])
    Chadcn::Chart::Polar::RadarPoints.call(series, rows: rows, angle_axis: angle, radius_axis: radius, view_box: VIEW_BOX)
  end

  test "a point per row: the category's angle (from the top, clockwise), the radius of its value" do
    list = points

    assert_equal 6, list.size
    assert_equal %w[January February March April May June], list.map(&:name)
    assert_in_delta 90.0, list.first.angle
    assert_in_delta 30.0, list[1].angle
    assert_in_delta 160.0, list.first.x
    assert_in_delta 55.825, list.first.y, 1e-9
    assert_in_delta 44.175, list.first.radius, 1e-9
    assert_equal [ 160, 100 ], [ list.first.cx, list.first.cy ]
    assert_same ROWS.first, list.first.row
  end

  test "a row without a value is at the center, a row without a category is named by its index" do
    list = points(rows: [ { month: "A", desktop: nil }, { desktop: 5 } ])

    assert_equal [ 0.0, nil ], [ list.first.radius, list.first.value ]
    assert_equal [ "A", 1 ], list.map(&:name)
  end

  test "a range value raises, naming the key" do
    error = assert_raises(ArgumentError) { points(rows: [ { month: "A", desktop: [ 1, 2 ] } ]) }

    assert_match(/radar ranges .* are not ported \(got \[1, 2\] for :desktop\)/, error.message)
  end
end

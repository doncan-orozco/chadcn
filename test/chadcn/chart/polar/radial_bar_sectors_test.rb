# frozen_string_literal: true

require_relative "polar_helper"

class Chadcn::Chart::Polar::RadialBarSectorsTest < Chadcn::TestCase
  include PolarHelper

  Settings = Chadcn::Chart::Polar::AxisSettings
  VIEW_BOX = Chadcn::Chart::Polar::ViewBox.new(cx: 160, cy: 100, inner_radius: 30, outer_radius: 100, start_angle: 0, end_angle: 360)
  ROWS = [ { browser: "a", visitors: 100, fill: "red" }, { browser: "b", visitors: 50 }, { browser: "c", visitors: nil } ].freeze

  def sectors(rows: ROWS, pairs: nil, cells: [], **)
    series = Chadcn::Chart::RadialBar.new(data_key: :visitors, **)
    cells.each { |cell| series.declare(cell) }
    angle = Chadcn::Chart::Polar::Axis.new(Settings.implicit(:angle), layout: :radial, rows: rows, items: [ series ], range: [ 0.0, 360.0 ])
    radius = Chadcn::Chart::Polar::Axis.new(Settings.implicit(:radius), layout: :radial, rows: rows, items: [ series ], range: [ 30.0, 100.0 ])
    position = Chadcn::Chart::Cartesian::BarPositions::Position.new(stack_id: nil, data_keys: [ :visitors ], offset: 2.0, size: 20.0)
    axes = { angle: angle, radius: radius }
    Chadcn::Chart::Polar::RadialBarSectors.call(series, rows: rows, axes: axes, view_box: VIEW_BOX, position: position, pairs: pairs)
  end

  test "an arc per row: from zero to its value along the angle axis, in the ring of its category" do
    list = sectors

    assert_equal 3, list.size
    assert_in_delta 360.0, list[0].end_angle
    assert_in_delta 180.0, list[1].end_angle
    assert_in_delta 0.0, list[0].start_angle
    assert_in_delta 32.0, list[0].inner_radius
    assert_in_delta 52.0, list[0].outer_radius
    assert_in_delta 55.333, list[1].inner_radius, 1e-3
    assert_equal 100, list[0].value
    assert_equal({ fill: "red" }, list[0].attributes)
  end

  test "a row without a value cannot be drawn, the others can" do
    list = sectors

    assert_predicate list[0], :drawable?
    refute_predicate list[2], :drawable?
    assert_nil list[2].end_angle
    assert_nil list[2].background
  end

  test "a background arc spans the whole angle of the chart in the ring of the bar" do
    background = sectors.first.background

    assert_equal [ 160, 100, 32.0, 52.0, 0.0, 360.0 ], background.values_at(:cx, :cy, :inner_radius, :outer_radius, :start_angle, :end_angle)
  end

  test "a minimum point size lengthens an arc that turns less" do
    rows = [ { browser: "a", visitors: 100 }, { browser: "b", visitors: 1 } ]

    assert_in_delta 40.0, sectors(rows: rows, min_point_size: 40)[1].end_angle - sectors(rows: rows, min_point_size: 40)[1].start_angle
    assert_in_delta 3.6, sectors(rows: rows)[1].end_angle, 1e-9
  end

  test "stacked pairs ride on each other and are cut to the domain of the angle axis" do
    pairs = [ [ 0.0, 60.0 ], [ 60.0, 150.0 ], [ 150.0, 400.0 ] ]
    list = sectors(pairs: pairs, stack_id: "a")

    assert_in_delta 216.0, list[0].end_angle
    assert_in_delta 216.0, list[1].start_angle
    assert_in_delta 360.0, list[1].end_angle
    assert_in_delta 360.0, list[2].start_angle
    assert_equal [ 60.0, 100.0 ], list[1].value
  end

  test "a cell gives the arc its attributes, over the row's" do
    list = sectors(cells: [ Chadcn::Chart::Cell.new(fill: "blue", class: "c") ])

    assert_equal({ fill: "blue", class: "c" }, list.first.attributes)
  end

  test "an array value is its own range" do
    rows = [ { browser: "a", visitors: [ 20, 60 ] }, { browser: "b", visitors: 100 } ]
    first = sectors(rows: rows).first

    assert_in_delta 72.0, first.start_angle
    assert_in_delta 216.0, first.end_angle
  end

  test "the view box of an arc is the sector it draws" do
    box = sectors.first.view_box

    assert_equal [ 160, 100, 32.0, 52.0, 0.0, 360.0 ], [ box.cx, box.cy, box.inner_radius, box.outer_radius, box.start_angle, box.end_angle ]
  end
end

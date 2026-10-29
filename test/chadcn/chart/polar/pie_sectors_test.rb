# frozen_string_literal: true

require_relative "polar_helper"

class Chadcn::Chart::Polar::PieSectorsTest < Chadcn::TestCase
  include PolarHelper

  PLOT = { x: 5.0, y: 5.0, width: 310.0, height: 190.0 }.freeze

  def sectors(rows: BROWSERS, cells: [], **)
    pie = Chadcn::Chart::Pie.new(data_key: :visitors, name_key: :browser, **)
    cells.each { |cell| pie.declare(cell) }
    Chadcn::Chart::Polar::PieSectors.call(pie, rows: rows, plot: PLOT)
  end

  test "sizes the sectors by value around the center of the plot, 80% of the largest circle" do
    list = sectors

    assert_equal 5, list.size
    assert_equal [ 160.0, 100.0, 0.0, 76.0 ], list.first.to_h.values_at(:cx, :cy, :inner_radius, :outer_radius)
    assert_in_delta 107.027, list.first.end_angle, 0.001
    assert_in_delta 360.0, list.last.end_angle, 1e-9
    assert_in_delta 275.0 / 925, list.first.percent, 1e-12
    assert_equal %w[chrome safari firefox edge other], list.map(&:name)
  end

  test "a share is a number of pixels or a percent of the plot and of the largest circle" do
    sector = sectors(cx: 100, cy: "30%", inner_radius: "20%", outer_radius: 50).first

    assert_equal [ 105.0, 62.0, 19.0, 50.0 ], sector.to_h.values_at(:cx, :cy, :inner_radius, :outer_radius)
  end

  test "padding, a minimum angle and the direction shape the angles" do
    padded = sectors(padding_angle: 5, min_angle: 10)
    clockwise = sectors(start_angle: 90, end_angle: -270)

    assert_in_delta 5.0, padded[1].start_angle - padded[0].end_angle, 1e-9
    assert_operator padded.map { |sector| sector.end_angle - sector.start_angle }.min, :>=, 10
    assert_in_delta 90.0, clockwise.first.start_angle
    assert_operator clockwise.last.end_angle, :<, clockwise.first.start_angle
  end

  test "nothing to size is no sector: no rows, all zero, nil and non-numeric values" do
    assert_empty sectors(rows: [])
    assert_empty sectors(rows: [ { browser: "a", visitors: 0 }, { browser: "b", visitors: nil }, { browser: "c", visitors: "12" } ])
    assert_equal [ 0.0, 360.0 ], sectors(rows: [ { browser: "a", visitors: nil }, { browser: "b", visitors: 4 } ]).map(&:end_angle).values_at(0, 1)
  end

  test "a row without a name is named by its index, and the row and the cell give the path their attributes" do
    cell = Chadcn::Chart::Cell.new(fill: "blue", class: "ccls")
    list = sectors(rows: [ { visitors: 1, fill: "red", opacity: 0.5 }, { visitors: 2, stroke: "green", name: "own" } ], cells: [ cell ])

    assert_equal [ 0, 1 ], list.map(&:name)
    assert_equal({ fill: "blue", opacity: 0.5, class: "ccls" }, list[0].attributes)
    assert_equal({ stroke: "green", name: "own" }, list[1].attributes)
  end

  test "presentation is the pie's props, then the name, the row's and the cell's attributes, then the center" do
    pie = Chadcn::Chart::Pie.new(data_key: :visitors, name_key: :browser, stroke_width: 5, class: "pcls", id: "mine", fill_opacity: 0.4)
    sector = Chadcn::Chart::Polar::PieSectors.call(pie, rows: BROWSERS, plot: PLOT).first
    shown = Chadcn::Chart::Polar::PieSectors.presentation(pie, sector)

    assert_equal "var(--color-chrome)", shown[:fill]
    assert_equal [ "#fff", 5, "pcls", 0.4, "chrome", 160.0 ], shown.values_at(:stroke, :stroke_width, :class, :fill_opacity, :name, :cx)
    refute_includes shown, :id
  end

  test "a corner radius written as text keeps its leading number, as parseFloat" do
    assert_equal [ 12.0, 6 ], [ sectors(corner_radius: "12px").first.corner_radius, sectors(corner_radius: 6).first.corner_radius ]
    assert_predicate sectors(corner_radius: "abc").first.corner_radius, :nan?
    assert_nil sectors.first.corner_radius
  end

  test "the tooltip position is the middle of the ring at the middle angle" do
    sector = sectors(inner_radius: 60).first
    x, y = sector.tooltip_position

    assert_in_delta 160 + (68 * Math.cos(-Math::PI * sector.mid_angle / 180)), x, 1e-9
    assert_in_delta 100 + (68 * Math.sin(-Math::PI * sector.mid_angle / 180)), y, 1e-9
  end
end

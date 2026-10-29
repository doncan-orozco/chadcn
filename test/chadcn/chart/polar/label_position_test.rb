# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Polar::LabelPositionTest < Chadcn::TestCase
  VIEW_BOX = Chadcn::Chart::Polar::ViewBox.new(cx: 160, cy: 100, inner_radius: 30, outer_radius: 70, start_angle: 0, end_angle: 90)
  POSITION = Chadcn::Chart::Polar::LabelPosition

  def place(position, offset: 5, view_box: VIEW_BOX) = POSITION.call(view_box: view_box, position: position, offset: offset)

  test "the middle of the ring is the default, at the middle angle" do
    where = place(:middle)

    assert_in_delta 160 + (50 * Math.cos(Math::PI / 4)), where.x, 1e-9
    assert_in_delta 100 - (50 * Math.sin(Math::PI / 4)), where.y, 1e-9
    assert_equal %i[middle middle], [ where.horizontal_anchor, where.vertical_anchor ]
    assert_equal where, place(:nowhere)
  end

  test "outside is past the rim by the offset, anchored to the side of the center it is on" do
    right = place(:outside)
    left = place(:outside, view_box: VIEW_BOX.with(start_angle: 180, end_angle: 270))

    assert_in_delta 160 + (75 * Math.cos(Math::PI / 4)), right.x, 1e-9
    assert_equal %i[start middle], [ right.horizontal_anchor, right.vertical_anchor ]
    assert_equal :end, left.horizontal_anchor
  end

  test "the centered positions sit on the center, hung from the top, the middle or the bottom" do
    assert_equal [ 160, 100, :middle, :middle ], place(:center).to_h.values
    assert_equal :start, place(:center_top).vertical_anchor
    assert_equal :end, place("centerBottom").vertical_anchor
  end

  test "the radial positions follow the arc: a path of almost a full turn from the angle the offset gives" do
    start = place(:inside_start)
    stop = place("insideEnd")
    after = place(:end)

    assert_kind_of POSITION::Radial, start
    assert_match(/\AM209\.\d+,95\.\d+\n    A50,50,0,1,0,\n    /, start.path)
    refute_equal start.path, stop.path
    refute_equal stop.path, after.path
    assert(%i[inside_start inside_end end].all? { |name| POSITION.radial?(name) })
    assert POSITION.radial?("insideStart")
    refute POSITION.radial?(:middle)
    refute POSITION.radial?(nil)
  end

  test "a sector running clockwise turns the text the other way" do
    forward = place(:inside_start)
    backward = place(:inside_start, view_box: VIEW_BOX.with(start_angle: 90, end_angle: 0))

    assert_match(/A50,50,0,1,0,/, forward.path)
    assert_match(/A50,50,0,1,1,/, backward.path)
  end
end

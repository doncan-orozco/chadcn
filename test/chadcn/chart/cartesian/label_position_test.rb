# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Cartesian::LabelPositionTest < Chadcn::TestCase
  LabelPosition = Chadcn::Chart::Cartesian::LabelPosition
  BOX = { x: 10.0, y: 50.0, width: 40.0, height: 30.0 }.freeze
  PARENT = { x: 0.0, y: 0.0, width: 320.0, height: 200.0 }.freeze

  def place(position, **) = LabelPosition.call(box: BOX, position: position, offset: 5, **)

  test "top sits above the box, centered, hanging from the bottom; the clamp is the room above" do
    top = place(:top, parent: PARENT)

    assert_equal [ 30.0, 45.0, :middle, :end ], [ top.x, top.y, top.horizontal_anchor, top.vertical_anchor ]
    assert_equal [ 40.0, 50.0 ], [ top.width, top.height ]
  end

  test "bottom, left and right are on the matching side" do
    bottom = place("bottom", parent: PARENT)
    left = place(:left, parent: PARENT)
    right = place(:right, parent: PARENT)

    assert_equal [ 30.0, 85.0, :start ], [ bottom.x, bottom.y, bottom.vertical_anchor ]
    assert_equal [ 5.0, 65.0, :end ], [ left.x, left.y, left.horizontal_anchor ]
    assert_equal [ 55.0, :start ], [ right.x, right.horizontal_anchor ]
    assert_in_delta 265.0, right.width
  end

  test "the inside positions are snake_case and keep the size of the box" do
    inside = place(:inside_top_left, parent: PARENT)

    assert_equal [ 15.0, 55.0, :start, :start ], [ inside.x, inside.y, inside.horizontal_anchor, inside.vertical_anchor ]
    assert_equal [ 40.0, 30.0 ], [ inside.width, inside.height ]
    assert_equal([ 45.0, 75.0 ], place(:inside_bottom_right).then { |result| [ result.x, result.y ] })
  end

  test "anything else, and a position without a parent, centers the label and has no size" do
    center = place(:middle)

    assert_equal [ 30.0, 65.0, :middle, :middle ], [ center.x, center.y, center.horizontal_anchor, center.vertical_anchor ]
    assert_nil center.width
    assert_equal([ 30.0, 65.0 ], place(:nonsense).then { |result| [ result.x, result.y ] })
  end

  test "a negative height flips the vertical anchors and the offset" do
    flipped = LabelPosition.call(box: { x: 0.0, y: 100.0, width: 10.0, height: -40.0 }, position: :top, offset: 5)

    assert_equal [ 105.0, :start ], [ flipped.y, flipped.vertical_anchor ]
  end

  test "a free position is a point inside the box, numbers or percents" do
    free = place({ x: "50%", y: 10 })

    assert_equal [ 30.0, 60.0, :end, :end ], [ free.x, free.y, free.horizontal_anchor, free.vertical_anchor ]
  end
end

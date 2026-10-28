# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Cartesian::RectangleTest < Chadcn::TestCase
  Rectangle = Chadcn::Chart::Cartesian::Rectangle

  test "no radius is a plain box" do
    assert_equal "M 1,2 h 10 v 20 h -10 Z", Rectangle.path(1, 2, 10, 20, nil)
    assert_equal "M 1,2 h 10 v 20 h -10 Z", Rectangle.path(1, 2, 10, 20, 0)
  end

  test "one radius rounds the four corners with recharts' multi-line template" do
    assert_equal "M 0,4\n            A 4,4,0,0,1,4,0\n            L 6,0\n            A 4,4,0,0,1,10,4\n            L 10,16\n            A 4,4,0,0,1,6,20\n            L 4,20\n            A 4,4,0,0,1,0,16 Z",
                 Rectangle.path(0, 0, 10, 20, 4)
  end

  test "a radius is capped by half the shorter side" do
    assert_includes Rectangle.path(0, 0, 4, 100, 50), "A 2,2,"
  end

  test "an array radius draws an arc only for a corner that has one" do
    assert_equal "M0,4A 4,4,0,0,1,4,0L 6,0A 4,4,0,0,1,\n        10,4L 10,20L 0,20Z", Rectangle.path(0, 0, 10, 20, [ 4, 4, 0, 0 ])
    assert_equal "M0,0L 10,0L 10,16A 4,4,0,0,1,\n        6,20L 4,20A 4,4,0,0,1,\n        0,16Z", Rectangle.path(0, 0, 10, 20, [ 0, 0, 4, 4 ])
  end

  test "a negative height flips the corners and the sweep" do
    path = Rectangle.path(0, 20, 10, -20, 4)

    assert_includes path, "M 0,16"
    assert_includes path, "A 4,4,0,0,0,"
  end

  test "numbers are rounded to four decimals and never print -0" do
    assert_equal 0.3333, Rectangle.round(1.0 / 3)
    assert_equal "M 0.3333,0 h 1 v 1 h -1 Z", Rectangle.path(1.0 / 3, -0.00001, 1, 1, nil)
  end
end

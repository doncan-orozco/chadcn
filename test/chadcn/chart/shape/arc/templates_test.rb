# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Shape::Arc::TemplatesTest < Chadcn::TestCase
  Templates = Chadcn::Chart::Shape::Arc::Templates

  test "outer_arc keeps the whitespace of the recharts template and prints the flags as 0 or 1" do
    path = Templates.outer_arc(from: [ 1.0, 2.0 ], to: [ 3.0, 4.0 ], radius: 5.0, large_arc: true, sweep: false)

    assert_equal "M 1,2\n    A 5,5,0,\n    1,0,\n    3,4\n  ", path
  end

  test "numbers are rounded to four decimals" do
    assert_equal "L 0.3333,0.6667 Z", Templates.center_close(1 / 3.0, 2 / 3.0)
  end

  test "inner_arc closes the path" do
    path = Templates.inner_arc(from: [ 1, 2 ], to: [ 3, 4 ], radius: 5, large_arc: false, sweep: true)

    assert_equal "L 1,2\n            A 5,5,0,\n            0,1,\n            3,4 Z", path
  end

  test "forced_corners draws the two corner arcs from the start line point" do
    assert_equal "M 1,2\n        a3,3,0,0,1,6,0\n        a3,3,0,0,1,-6,0\n      ", Templates.forced_corners(start_line: [ 1, 2 ], corner: 3)
  end

  test "center_corners rounds and center_corners_unrounded does not" do
    assert_equal "L1.2346,2Z", Templates.center_corners(1.23456789, 2)
    assert_equal "L1.23456789,2Z", Templates.center_corners_unrounded(1.23456789, 2)
  end

  test "outer_corners and inner_corners place the corner sweep in every corner arc" do
    points = { start_line: [ 1, 1 ], start_circle: [ 2, 2 ], end_circle: [ 3, 3 ], end_line: [ 4, 4 ], corner: 1, radius: 9, large_arc: true }
    outer = Templates.outer_corners(**points, corner_sweep: true)
    inner = Templates.inner_corners(**points, corner_sweep: false, arc_sweep: true)

    assert_equal 2, outer.scan("A1,1,0,0,1,").size
    assert_includes outer, "A9,9,0,1,1,"
    assert_includes inner, "A9,9,0,1,1,"
    assert_equal 2, inner.scan("A1,1,0,0,0,").size
  end
end

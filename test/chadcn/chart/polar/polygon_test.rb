# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Polar::PolygonTest < Chadcn::TestCase
  PATH = Chadcn::Chart::Polar::Polygon

  test "a closed path through the corners, each number rounded to four decimals" do
    corners = [ [ 160, 55.824999999999996 ], [ 222.7327151866353, 63.78125000000001 ], [ 208.7464049155166, 128.14375 ] ]

    assert_equal "M160,55.825L222.7327,63.7813L208.7464,128.1438L160,55.825Z", PATH.path(corners)
  end

  test "no corner is no path" do
    assert_nil PATH.path([])
    assert_nil PATH.path([ [ Float::NAN, 1 ] ])
  end

  test "a corner that is not a pair of numbers breaks the polygon in two, and the first corner joins the last piece" do
    assert_equal "M0,0L1,1M3,3L0,0", PATH.path([ [ 0, 0 ], [ 1, 1 ], [ nil, 2 ], [ 3, 3 ] ])
  end

  test "a lone corner is a move and a close" do
    assert_equal "M1,2L1,2Z", PATH.path([ [ 1, 2 ] ])
  end
end

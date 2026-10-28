# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Cartesian::TextTest < Chadcn::TestCase
  def text(**options) = Chadcn::Chart::Cartesian::Text.new(**options)

  test "a character is char_width em of the 12px font wide, a line is line_height tall" do
    assert_in_delta 21.6, text.width("Jan"), 0.0001
    assert_in_delta 18.0, text(char_width: 0.5).width("abc"), 0.0001
    assert_equal 16.0, text.line_height
    assert_equal 0.0, text.width(nil)
  end

  test "words are broken into lines that fit the width, and kept on one line without a width" do
    assert_equal [ "New York City" ], text.lines("New York City")
    assert_equal [ "New York City" ], text.lines("New York City", width: 0)
    assert_equal [ "New York", "City" ], text.lines("New York City", width: 70)
    assert_equal [ "San", "Francisco", "Bay" ], text.lines("San Francisco Bay", width: 60)
    assert_equal [ "" ], text.lines("", width: 50)
    assert_equal [ "Averyveryverylongword" ], text.lines("Averyveryverylongword", width: 50)
  end

  test "the first line hangs on the anchor: start below it, end above it, middle centered" do
    assert_equal "0.71em", text.first_dy(:start, 1)
    assert_equal "0em", text.first_dy(:end, 1)
    assert_equal "-1em", text.first_dy(:end, 2)
    assert_equal "0.355em", text.first_dy(:middle, 1)
    assert_equal "-0.14500000000000002em", text.first_dy(:middle, 2)
  end
end

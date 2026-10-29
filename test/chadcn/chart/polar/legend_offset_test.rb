# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Polar::LegendOffsetTest < Chadcn::TestCase
  MARGIN = { top: 5.0, right: 5.0, bottom: 5.0, left: 5.0 }.freeze

  def offset(**legend) = Chadcn::Chart::Polar::LegendOffset.call(MARGIN, Chadcn::Chart::Legend.new(**legend).options, 28)

  test "without a legend the margin is the offset" do
    assert_equal MARGIN, Chadcn::Chart::Polar::LegendOffset.call(MARGIN, nil, nil)
  end

  test "a horizontal legend takes its height from the side it sits on" do
    assert_in_delta 33.0, offset[:bottom]
    assert_in_delta 33.0, offset(vertical_align: :top)[:top]
    assert_equal MARGIN, offset(vertical_align: :middle)
  end

  test "a vertical legend beside the plot takes its width, one in the middle takes its height" do
    assert_in_delta 105.0, offset(layout: :vertical, align: :left, width: 100)[:left]
    assert_in_delta 5.0, offset(layout: :vertical, align: :right)[:right]
    assert_in_delta 33.0, offset(layout: :vertical, align: :center)[:bottom]
  end
end

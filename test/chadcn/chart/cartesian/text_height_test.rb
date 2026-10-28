# frozen_string_literal: true

require_relative "chart_helper"

# `text_height:` is the server's assumption for a line of tick text. It decides how far the last tick of a vertical axis is pulled inside the
# plot (recharts:cartesian/getTicks.js `getTicksEnd`): the gem default is 16 (the shadcn examples' 12px/16px); the parity page measures 18
# (ShadcnParity::ChartScope::PAGE_TEXT_HEIGHT, dev/port/specs/chart.md "Oracle driving"). G2 gates 18 only, so 16 is locked here.
class Chadcn::Chart::Cartesian::TextHeightTest < Chadcn::TestCase
  include ChartHelper

  def top_tick_y(**container)
    html = render_chart(Chadcn::Chart::LineChart, container: container, margin: { left: 12, right: 12 }) do |chart|
      chart.y_axis(tick_line: false, axis_line: false, tick_margin: 8)
      chart.x_axis(data_key: :month)
      chart.line(data_key: :desktop)
    end
    parse(html).css("text.recharts-cartesian-axis-tick-value[orientation=left]").map { |node| node["y"] }.last
  end

  test "the default 16px line pulls the top tick of a vertical axis 8px inside the chart" do
    assert_equal "8", top_tick_y
  end

  test "an 18px line (the parity page) pulls it 9px inside, as recharts measures there" do
    assert_equal "9", top_tick_y(text_height: 18)
  end
end

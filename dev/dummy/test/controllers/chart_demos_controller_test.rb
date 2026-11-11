# frozen_string_literal: true

require "test_helper"

class ChartDemosControllerTest < ActionDispatch::IntegrationTest
  test "each family renders a wired chart with Turbo Drive on" do
    %w[bar line area].each do |family|
      get "/design-system/chart-demo/#{family}"

      assert_response :success
      assert_select "div[data-slot=chart][data-controller~='chadcn--chart']"
      assert_select ".recharts-wrapper[data-action*='chadcn--chart#move']"
      assert_select "svg[data-chadcn--chart-target=surface]"
      assert_select ".recharts-tooltip-wrapper[data-chadcn--chart-target=tooltip]"
      assert_select "a#to-other[href='/design-system/chart-demo/other']"
      assert_select "body[data-turbo=false]", count: 0
    end
  end

  test "the click chart follows clicks and the line chart has a default index" do
    get "/design-system/chart-demo/area"
    assert_select "div[data-slot=chart][data-chadcn--chart-trigger-value=click]"

    get "/design-system/chart-demo/line"
    assert_select "div[data-slot=chart][data-chadcn--chart-default-index-value='2']"
  end

  test "the other page links back and an unknown family is a 404" do
    get "/design-system/chart-demo/other"
    assert_response :success
    assert_select "a#to-bar"

    get "/design-system/chart-demo/unknown"
    assert_response :not_found
  end

  # Since item #110 (dev/port/specs/chart.md, "Polar pointer and keyboard as built") every polar chart with a tooltip carries every action
  # of the controller on its `.recharts-wrapper`: a radar picks a category by the pointer's angle, a radial bar chart by its radius (both
  # axis tooltips whose templates carry the pointer cursor), a pie follows its sectors (an item tooltip, no cursor).
  test "the polar families wire the pointer and the keys with their own layout and tooltip" do
    action = Chadcn::Chart::Polar::Wiring::ACTION
    { "pie" => %w[item centric], "radar" => %w[axis centric], "radial" => %w[axis radial] }.each do |family, (event_type, layout)|
      get "/design-system/chart-demo/#{family}"

      assert_response :success
      chart = "div[data-slot=chart][data-controller~='chadcn--chart']"
      assert_select "#{chart}[data-chadcn--chart-default-index-value='1']"
      assert_select "#{chart}[data-chadcn--chart-tooltip-event-type-value=#{event_type}]"
      assert_select "#{chart}[data-chadcn--chart-layout-value=#{layout}][data-chadcn--chart-keyboard-step-value='1']"
      assert_select "#{chart}[data-chadcn--chart-polar-value]"
      assert_select ".recharts-wrapper[data-action=?]", action
    end
  end

  test "radar and radial templates carry the pointer cursor, the pie's sectors are the tooltip items" do
    %w[radar radial].each do |family|
      get "/design-system/chart-demo/#{family}"
      assert_select "template[data-pointer-cursor]", minimum: 1
      assert_select "[data-chadcn--chart-target=tooltipItem]", count: 0
    end

    get "/design-system/chart-demo/pie"
    assert_select "template[data-pointer-cursor]", count: 0
    assert_select "g.recharts-pie-sector[data-chadcn--chart-target=tooltipItem][data-chadcn--chart-series='0']", minimum: 1
  end
end

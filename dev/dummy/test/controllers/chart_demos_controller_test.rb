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

  test "the polar families publish their tooltip values and no action" do
    { "pie" => "item", "radar" => "axis" }.each do |family, event_type|
      get "/design-system/chart-demo/#{family}"

      assert_response :success
      assert_select "div[data-slot=chart][data-controller~='chadcn--chart'][data-chadcn--chart-default-index-value='1']"
      assert_select "div[data-slot=chart][data-chadcn--chart-tooltip-event-type-value=#{event_type}]"
      assert_select ".recharts-wrapper[data-action]", count: 0
    end
  end
end

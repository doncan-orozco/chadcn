# frozen_string_literal: true

require "test_helper"

class TurboRoundTripsControllerTest < ActionDispatch::IntegrationTest
  test "page one renders the components and a link to page two, with Turbo Drive on" do
    get "/design-system/turbo-round-trip/one"

    assert_response :success
    assert_select "#round-trip-collapsible[data-controller~='chadcn--collapsible']"
    assert_select "[data-controller~='chadcn--dialog'][data-chadcn--dialog-id-value='round-trip-dialog']"
    assert_select "a#to-two[href='/design-system/turbo-round-trip/two']"
    assert_select "body[data-turbo=false]", count: 0
  end

  test "page two links back to page one" do
    get "/design-system/turbo-round-trip/two"

    assert_response :success
    assert_select "a#to-one[href='/design-system/turbo-round-trip/one']"
  end

  test "an unknown page is a 404" do
    get "/design-system/turbo-round-trip/three"

    assert_response :not_found
  end
end

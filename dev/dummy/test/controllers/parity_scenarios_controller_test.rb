# frozen_string_literal: true

require "test_helper"

class ParityScenariosControllerTest < ActionDispatch::IntegrationTest
  test "renders a scenario tree inside the parity page" do
    get "/design-system/parity/_harness/nested"

    assert_response :success
    assert_select "body[data-turbo=false] [data-slot=probe-group]"
  end

  test "the helpers mode renders the same markup" do
    get "/design-system/parity/_harness/nested"
    plain = response.body
    get "/design-system/parity/_harness/nested", params: { dx: "helpers" }

    assert_response :success
    assert_equal plain, response.body
  end

  test "an unknown scenario is a 404 with the parity error element" do
    get "/design-system/parity/_harness/ghost"

    assert_response :not_found
    assert_select "[data-parity-error]", /NotFound/
  end

  test "an invalid component name is a 404" do
    get "/design-system/parity/nope/default"

    assert_response :not_found
    assert_select "[data-parity-error]"
  end

  test "a failing render is a 500 with the parity error element" do
    original = ShadcnParity::Scenario.method(:find)
    ShadcnParity::Scenario.define_singleton_method(:find) { |*| raise "boom" }
    begin
      get "/design-system/parity/_harness/nested"
    ensure
      ShadcnParity::Scenario.define_singleton_method(:find, original)
    end

    assert_response :internal_server_error
    assert_select "[data-parity-error]", /boom/
  end
end

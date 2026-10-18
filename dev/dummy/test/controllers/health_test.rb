# frozen_string_literal: true

require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  test "GET /up answers 200" do
    get "/up"

    assert_response :success
  end
end

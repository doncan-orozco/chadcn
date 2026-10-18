# frozen_string_literal: true

require "test_helper"

class ThemePanelsControllerTest < ActionDispatch::IntegrationTest
  test "renders the theme panel with a preset select" do
    get "/design-system/theme-panel"

    assert_response :success
    assert_select "select[data-shadcn--theme-panel-target=preset] option[value=zinc]"
  end
end

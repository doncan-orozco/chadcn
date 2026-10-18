# frozen_string_literal: true

require "test_helper"

class ShadcnParity::PageTest < ActiveSupport::TestCase
  test "disables Turbo Drive on the body like the Turbo-less React harness" do
    html = ApplicationController.new.view_context.render(ShadcnParity::Page.new(html: "<p>x</p>"))

    assert_match(/<body[^>]*data-turbo="false"/, html)
  end

  test "an error renders the data-parity-error element instead of the content" do
    html = ApplicationController.new.view_context.render(ShadcnParity::Page.new(error: "Boom: nope"))

    assert_match(/data-parity-error/, html)
    assert_includes html, "Boom: nope"
  end
end

# frozen_string_literal: true

require_relative "engine_helper"
require "nokogiri"
require "rack/mock"

# With the engine the counters behind the generated ids live for one request: a page assembled from several renders (layout,
# view, Turbo frames) never repeats an id, and the next request starts again from one.
class EngineTest::Sequences < Minitest::Test
  # Two top-level renders of a DropdownMenu, each with its own Phlex context, as a layout and a view produce them.
  MENUS = lambda do |_env|
    html = Array.new(2) { Chadcn::DropdownMenu.new.call { |menu| menu.trigger { "Open" } } }.join
    [ 200, { "content-type" => "text/html" }, [ html ] ]
  end

  def app = EngineTest::Application

  def setup
    app.routes.draw { get "/menus", to: MENUS } if app.routes.routes.none? { |route| route.path.spec.to_s == "/menus" }
  end

  def trigger_ids(path)
    status, _headers, body = app.call(Rack::MockRequest.env_for(path))

    assert_equal 200, status
    html = +""
    body.each { |chunk| html << chunk }
    Nokogiri::HTML5.fragment(html).css("[data-slot=dropdown-menu-trigger]").map { |trigger| trigger["id"] }
  end

  def test_the_engine_installs_a_sequence_store
    assert_respond_to Chadcn.config.sequence_store, :call
  end

  def test_two_renders_in_one_request_produce_different_ids
    assert_equal %w[dropdown-menu-1-trigger dropdown-menu-2-trigger], trigger_ids("/menus")
  end

  def test_each_request_numbers_its_roots_from_one
    assert_equal trigger_ids("/menus"), trigger_ids("/menus")
  end
end

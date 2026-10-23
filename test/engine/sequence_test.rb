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
    app.routes.draw { get "/menus", to: MENUS } if app.routes.routes.none? { |route| route.path.spec.to_s == "/menus(.:format)" }
  end

  def trigger_ids(path)
    status, _headers, body = app.call(Rack::MockRequest.env_for(path))

    assert_equal 200, status
    html = +""
    body.each { |chunk| html << chunk }
    body.close if body.respond_to?(:close) # completes the request: the executor resets the counters here
    Nokogiri::HTML5.fragment(html).css("[data-slot=dropdown-menu-trigger]").map { |trigger| trigger["id"] }
  end

  def run_sequence_store_initializer
    Chadcn::Engine.instance.initializers.find { |initializer| initializer.name == "chadcn.sequence_store" }.run(app)
  end

  def test_the_engine_installs_a_store_answering_a_hash
    store = app.executor.wrap { Chadcn.config.sequence_store.call }

    assert_kind_of Hash, store
  end

  def test_two_renders_in_one_request_produce_different_ids
    assert_equal %w[dropdown-menu-1-trigger dropdown-menu-2-trigger], trigger_ids("/menus")
  end

  def test_each_request_numbers_its_roots_from_one
    2.times { assert_equal %w[dropdown-menu-1-trigger dropdown-menu-2-trigger], trigger_ids("/menus") }
  end

  def test_a_store_set_with_configure_is_kept
    previous = Chadcn.config.sequence_store
    own = -> { {} }
    Chadcn.config.sequence_store = own
    run_sequence_store_initializer

    assert_same own, Chadcn.config.sequence_store
  ensure
    Chadcn.config.sequence_store = previous
  end

  def test_the_engine_store_lives_for_one_execution
    store = Chadcn.config.sequence_store
    first = app.executor.wrap { [ store.call, store.call ] }
    second = app.executor.wrap { store.call }

    assert_same first.first, first.last
    refute_same first.first, second
  end
end

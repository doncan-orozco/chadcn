# frozen_string_literal: true

require "test_helper"

class SmokeTest < Minitest::Test
  def test_has_a_version
    assert_match(/\A\d+\.\d+\.\d+/, Phlex::Shadcn::VERSION)
  end

  def test_loads_without_rails
    assert_nil defined?(Rails), "the gem core must load without Rails"
  end

  def test_eager_loads_every_file
    Phlex::Shadcn::Loader.eager_load

    assert_kind_of Module, Phlex::Shadcn
  end
end

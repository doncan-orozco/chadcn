# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::DirectionTest < Phlex::Shadcn::TestCase
  class Probe < Phlex::Shadcn::Base
    include Phlex::Shadcn::Direction::Consumer

    def initialize(dir: nil)
      @dir = dir
      super()
    end

    def view_template
      span { use_direction(@dir) }
    end
  end

  class Page < Phlex::Shadcn::Base
    def view_template
      render Probe.new
      render Phlex::Shadcn::Direction::Provider.new(direction: :rtl) do
        render Probe.new
        render Probe.new(dir: "ltr")
        render Phlex::Shadcn::Direction::Provider.new(dir: nil) { render Probe.new }
      end
      render Probe.new
    end
  end

  test "provider renders no markup and scopes the value" do
    assert_equal "<span>ltr</span><span>rtl</span><span>ltr</span><span>ltr</span><span>ltr</span>", Page.new.call
  end

  test "direction wins over dir" do
    html = Phlex::Shadcn::Direction::Provider.new(dir: "ltr", direction: "rtl").call { "x" }

    assert_equal "x", html
  end

  test "rejects invalid values" do
    assert_raises(ArgumentError) { Phlex::Shadcn::Direction::Provider.new(dir: "up") }
  end
end

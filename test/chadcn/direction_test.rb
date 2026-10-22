# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::DirectionTest < Chadcn::TestCase
  class Probe < Chadcn::Base
    include Chadcn::Direction::Consumer

    def initialize(dir: nil)
      @dir = dir
      super()
    end

    def view_template
      span { use_direction(@dir) }
    end
  end

  class Page < Chadcn::Base
    def view_template
      render Probe.new
      render Chadcn::Direction::Provider.new(direction: :rtl) do
        render Probe.new
        render Probe.new(dir: "ltr")
        render Chadcn::Direction::Provider.new(dir: nil) { render Probe.new }
      end
      render Probe.new
    end
  end

  test "provider renders no markup and scopes the value" do
    assert_equal "<span>ltr</span><span>rtl</span><span>ltr</span><span>rtl</span><span>ltr</span>", Page.new.call
  end

  test "a nested provider without a direction keeps the outer one, and an inner one overrides it" do
    page = Class.new(Chadcn::Base) do
      define_method(:view_template) do
        render(Chadcn::Direction::Provider.new(dir: "rtl")) do
          render(Chadcn::Direction::Provider.new) { render Probe.new }
          render(Chadcn::Direction::Provider.new(direction: "ltr")) { render Probe.new }
          render Probe.new
        end
      end
    end

    assert_equal "<span>rtl</span><span>ltr</span><span>rtl</span>", page.new.call
  end

  test "direction wins over dir" do
    page = Class.new(Chadcn::Base) do
      define_method(:view_template) do
        render(Chadcn::Direction::Provider.new(dir: "ltr", direction: "rtl")) { render Probe.new }
      end
    end

    assert_equal "<span>rtl</span>", page.new.call
  end

  test "rejects invalid values" do
    assert_raises(ArgumentError) { Chadcn::Direction::Provider.new(dir: "up") }
  end

  test "use_direction prefers the local value, then the provider value, then ltr" do
    key = Chadcn::Direction::KEY

    assert_equal "rtl", Chadcn::Direction.use_direction({}, :rtl)
    assert_equal "ltr", Chadcn::Direction.use_direction({})
    assert_equal "ltr", Chadcn::Direction.use_direction({ key => "" }, "")
    assert_equal "rtl", Chadcn::Direction.use_direction({ key => "rtl" })
    assert_equal "ltr", Chadcn::Direction.use_direction({ key => "rtl" }, "ltr")
  end

  test "the namespace class renders nothing and lists its values" do
    assert_equal "", Chadcn::Direction.new.call
    assert_equal %w[ltr rtl], Chadcn::Direction::VALUES
  end

  test "provider restores the previous direction when the block raises" do
    page = Class.new(Chadcn::Base) do
      define_method(:view_template) do
        render(Chadcn::Direction::Provider.new(dir: :rtl)) { raise "boom" }
      rescue RuntimeError
        render Probe.new
      end
    end

    assert_equal "<span>ltr</span>", page.new.call
  end
end

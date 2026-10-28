# frozen_string_literal: true

require "chadcn/test_case"

# tailwind_merge 1.5.6 maps the overflow-y group to the overscroll scale, so `overflow-y-scroll` is not a value of the group and
# does not override `overflow-y-auto`. Chadcn::Base patches the group to the overflow scale.
class Chadcn::BaseClassMergeTest < Chadcn::TestCase
  def merge(classes) = Chadcn::Base.tw_merger.merge(classes)

  test "overflow-y values override each other" do
    assert_equal "overflow-y-scroll", merge("overflow-y-auto overflow-y-scroll")
    assert_equal "overflow-y-hidden", merge("overflow-y-clip overflow-y-visible overflow-y-hidden")
  end

  test "overflow-y and overscroll-y stay independent" do
    assert_equal "overflow-y-auto overscroll-y-contain", merge("overflow-y-auto overscroll-y-contain")
  end

  test "overflow still overrides overflow-y" do
    assert_equal "overflow-hidden", merge("overflow-y-auto overflow-hidden")
  end
end

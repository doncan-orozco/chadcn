# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Cartesian::ScopeTest < Chadcn::TestCase
  Scope = Chadcn::Chart::Cartesian::Scope

  test "with publishes a scope for the block and puts the previous one back" do
    context = {}
    outer = Object.new
    inner = Object.new

    assert_nil Scope.current(context)
    Scope.with(context, outer) do
      assert_same outer, Scope.current(context)
      Scope.with(context, inner) { assert_same inner, Scope.current(context) }
      assert_same outer, Scope.current(context)
    end
    assert_nil Scope.current(context)
  end

  test "the scope is removed even when the block raises" do
    context = {}
    assert_raises(RuntimeError) { Scope.with(context, Object.new) { raise "boom" } }
    assert_nil Scope.current(context)
  end
end

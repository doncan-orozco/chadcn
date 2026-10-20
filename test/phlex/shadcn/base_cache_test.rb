# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::BaseCacheTest < Phlex::Shadcn::TestCase
  class Probe < Phlex::Shadcn::Base
    public :cn, :merge_attrs, :normalize_option

    def slot!(value) = receive_slot({}, value)
  end

  def setup = Phlex::Shadcn::Base.cn_cache.clear

  test "cached cn equals an uncached merge, on a miss and on a hit" do
    expected = TailwindMerge::Merger.new.merge("px-2 py-1 px-4")

    2.times { assert_equal expected, Probe.new.cn("px-2 py-1", "px-4") }
  end

  test "key covers defaults and caller class; the slot class is joined outside the cache" do
    probe = Probe.new

    assert_equal "px-4", probe.cn("px-2", "px-4")
    assert_equal "px-2", probe.cn("px-2", nil)

    first = Probe.new
    first.slot!("slot-a")
    other = Probe.new
    other.slot!("slot-b")

    assert_equal "slot-a px-2 text-sm", first.merge_attrs({ class: "px-2" }, { class: "text-sm" })[:class]
    assert_equal "slot-b px-2 text-sm", other.merge_attrs({ class: "px-2" }, { class: "text-sm" })[:class]
    assert_equal "px-2 text-sm", Probe.new.merge_attrs({ class: "px-2" }, { class: "text-sm" })[:class]
  end

  test "non string inputs bypass the cache" do
    probe = Probe.new

    assert_equal "a c", probe.cn("a", { "c" => true, "d" => false })
    assert_empty Phlex::Shadcn::Base.cn_cache
  end

  test "the cache is bounded" do
    probe = Probe.new
    (Phlex::Shadcn::Base.const_get(:CN_CACHE_LIMIT) * 2).times { |i| probe.cn("m-#{i}", "p-1") }

    assert_operator Phlex::Shadcn::Base.cn_cache.size, :<=, Phlex::Shadcn::Base.const_get(:CN_CACHE_LIMIT)
  end

  test "the cache keeps its own frozen copy of a mutable caller string" do
    caller_class = +"px-2"
    Probe.new.cn("p-1", caller_class)
    key = Phlex::Shadcn::Base.cn_cache.keys.first

    assert_predicate key, :frozen?
    assert(key.compact.all?(&:frozen?))
    refute_same caller_class, key.last
    caller_class << " hidden"

    assert_equal %w[p-1 px-2], key
    assert_equal "p-1 px-2", Probe.new.cn("p-1", "px-2")
  end

  test "argument order is part of the key" do
    probe = Probe.new

    assert_equal "px-4", probe.cn("px-2", "px-4")
    assert_equal "px-2", probe.cn("px-4", "px-2")
  end

  test "returned classes are frozen and merge_attrs never shares a hash" do
    probe = Probe.new

    assert_predicate probe.cn("p-1", "m-1"), :frozen?
    one = probe.merge_attrs({ class: "p-1", data: { a: 1 } }, {})
    one[:data][:a] = 2
    one[:class] = +"mutated"
    two = probe.merge_attrs({ class: "p-1", data: { a: 1 } }, {})

    assert_equal({ a: 1 }, two[:data])
    assert_equal "p-1", two[:class]
  end

  test "safe under concurrent use" do
    results = Array.new(8) do |t|
      Thread.new { Array.new(300) { |i| [ "px-#{(i + t) % 40}", Probe.new.cn("px-#{i % 40}", "px-#{(i + t) % 40}") ] } }
    end.flat_map(&:value)

    results.each { |expected, css| assert_equal expected, css }
  end

  test "normalize_option keeps its results, frozen and never the caller's object" do
    probe = Probe.new
    caller_value = +"outline"

    assert_equal "icon-sm", probe.normalize_option(:icon_sm)
    assert_equal "icon-sm", probe.normalize_option("icon_sm")
    assert_predicate probe.normalize_option("icon_sm"), :frozen?
    result = probe.normalize_option(caller_value)

    assert_equal "outline", result
    assert_predicate result, :frozen?
    refute_same caller_value, result
    assert_nil probe.normalize_option(nil)
  end
end

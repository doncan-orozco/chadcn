# frozen_string_literal: true

require "open3"
require "phlex/test_case"

class Phlex::Shadcn::BaseCacheTest < Phlex::Shadcn::TestCase
  class Probe < Phlex::Shadcn::Base
    public :cn, :merge_attrs, :normalize_option

    def slot!(value) = receive_slot({}, value)
  end

  def setup = Phlex::Shadcn::Base.clear_cn_cache

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

  # First use runs in a fresh process: the merger is slowed down (every `Merger.new` sleeps, so a lazy memo would let
  # many threads build one) BEFORE the gem loads, then a barrier releases the threads at once on a cold cache.
  RACE_SCRIPT = <<~RUBY
    require "tailwind_merge"
    $built = Queue.new
    TailwindMerge::Merger.singleton_class.prepend(Module.new do
      def new(...)
        $built << 1
        sleep 0.02
        super
      end
    end)
    require "phlex/shadcn"
    base = Phlex::Shadcn::Base
    built_at_load = $built.size
    probe = Class.new(base) { public :cn }
    ready = Queue.new
    go = Queue.new
    threads = Array.new(24) do |t|
      Thread.new do
        ready << t
        go.pop
        [base.tw_merger.object_id, probe.tw_merger.object_id, probe.new.cn("px-2 py-1", "px-4"), base.cn_cache.frozen?]
      end
    end
    24.times { ready.pop }
    24.times { go << true }
    results = threads.map(&:value)
    puts [built_at_load, $built.size, results.flat_map { |r| r[0, 2] }.uniq.size, results.map { |r| r[2] }.uniq.inspect, results.all? { |r| r[3] }].join("|")
  RUBY

  test "first use from many threads shares one merger and one cache, built at load" do
    lib = File.expand_path("../../../lib", __dir__)
    out, err, status = Open3.capture3(RbConfig.ruby, "-I", lib, "-e", RACE_SCRIPT)

    assert_predicate status, :success?, err
    # mergers built at load, mergers built after the threads started, distinct mergers seen, distinct results, frozen snapshots
    assert_equal "1|1|1|[\"py-1 px-4\"]|true", out.strip
  end

  test "cn_cache is a frozen snapshot, never the live hash" do
    Probe.new.cn("p-1", "m-1")
    snapshot = Phlex::Shadcn::Base.cn_cache

    assert_predicate snapshot, :frozen?
    assert_equal 1, snapshot.size
    assert_raises(FrozenError) { snapshot.clear }
    Probe.new.cn("p-2", "m-2")

    assert_equal 1, snapshot.size
    assert_equal 2, Phlex::Shadcn::Base.cn_cache.size
  end

  test "subclasses share the one merger and the one cache" do
    assert_same Phlex::Shadcn::Base.tw_merger, Probe.tw_merger
    Probe.new.cn("p-1", "m-1")

    assert_equal 1, Phlex::Shadcn::Base.cn_cache.size
    assert_equal 1, Probe.cn_cache.size
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

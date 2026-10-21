# frozen_string_literal: true

require "phlex/test_case"

# `data-controller` is a list of Stimulus identifiers, so a caller's controllers are appended to the component's own ones
# instead of replacing them (see dev/decisions/data-controller-merge.md).
class Phlex::Shadcn::BaseMergeAttrsTest < Phlex::Shadcn::TestCase
  class Probe < Phlex::Shadcn::Base
    public :merge_attrs
  end

  def controllers(attrs) = attrs.dig(:data, :controller)

  test "a component controller and a caller controller yield both, component first" do
    merged = Probe.new.merge_attrs({ data: { controller: "shadcn--x" } }, { data: { controller: "mine other" } })

    assert_equal "shadcn--x mine other", controllers(merged)
  end

  test "flat data-controller keys merge the same way" do
    merged = Probe.new.merge_attrs({ "data-controller": "shadcn--x" }, { "data-controller" => "mine" })

    assert_equal "shadcn--x mine", controllers(merged)
  end

  test "a caller controller on a component without one is kept" do
    assert_equal "mine", controllers(Probe.new.merge_attrs({ data: { slot: "x" } }, { data: { controller: "mine" } }))
    assert_equal "shadcn--x", controllers(Probe.new.merge_attrs({ data: { controller: "shadcn--x" } }, {}))
  end

  test "duplicates collapse, whatever the spacing" do
    merged = Probe.new.merge_attrs({ data: { controller: "shadcn--x" } }, { data: { controller: " shadcn--x  mine\nmine " } })

    assert_equal "shadcn--x mine", controllers(merged)
  end

  test "other data keys still deep-merge with the caller winning" do
    merged = Probe.new.merge_attrs({ data: { controller: "a", slot: "s", state: "closed" } }, { data: { controller: "b", state: "open" } })

    assert_equal({ controller: "a b", slot: "s", state: "open" }, merged[:data])
  end

  test "data-action keeps concatenating alongside the controller merge" do
    merged = Probe.new.merge_attrs({ data: { controller: "a", action: "click->a#go" } }, { data: { controller: "b", action: "click->b#go" } })

    assert_equal "a b", controllers(merged)
    assert_equal "click->a#go click->b#go", merged.dig(:data, :action)
  end

  test "the hashes the caller holds are not mutated" do
    defaults = { data: { controller: "a" }.freeze, class: "p-2" }.freeze
    caller_attrs = { data: { controller: "b" }.freeze, class: "p-4" }.freeze

    merged = Probe.new.merge_attrs(defaults, caller_attrs)

    assert_equal "a b", controllers(merged)
    assert_equal "a", defaults[:data][:controller]
    assert_equal "b", caller_attrs[:data][:controller]
  end

  test "an explicit nil or blank caller controller keeps the component's" do
    assert_equal "shadcn--x", controllers(Probe.new.merge_attrs({ data: { controller: "shadcn--x" } }, { data: { controller: nil } }))
    assert_equal "shadcn--x", controllers(Probe.new.merge_attrs({ data: { controller: "shadcn--x" } }, { "data-controller" => "  " }))
  end

  test "array, set and symbol controllers are token lists" do
    defaults = { data: { controller: "shadcn--x" } }

    assert_equal "shadcn--x a b", controllers(Probe.new.merge_attrs(defaults, { data: { controller: %w[a b] } }))
    assert_equal "shadcn--x a", controllers(Probe.new.merge_attrs(defaults, { data: { controller: Set["a", "shadcn--x"] } }))
    assert_equal "shadcn--x a", controllers(Probe.new.merge_attrs(defaults, { data: { controller: :a } }))
  end

  test "Calendar keeps shadcn--calendar when the caller passes controller: nil" do
    out = Phlex::Shadcn::Calendar.new(today: "2026-03-15", data: { controller: nil }).call

    assert_equal "shadcn--calendar", Nokogiri::HTML5.fragment(out).at_css("[data-slot=calendar]")["data-controller"]
  end

  test "Calendar keeps shadcn--calendar when the caller passes a controller" do
    out = Phlex::Shadcn::Calendar.new(today: "2026-03-15", data: { controller: "x" }).call
    root = Nokogiri::HTML5.fragment(out).at_css("[data-slot=calendar]")

    assert_equal "shadcn--calendar x", root["data-controller"]
    assert_includes out, "data-shadcn--calendar-config-value"
  end

  test "Sonner toaster keeps shadcn--sonner when the caller passes a controller" do
    out = Phlex::Shadcn::Sonner::Toaster.new(data: { controller: "x" }).call

    assert_equal "shadcn--sonner x", Nokogiri::HTML5.fragment(out).at_css("section")["data-controller"]
  end

  test "as_child merges controllers through the slot and the child's own defaults" do
    out = Phlex::Shadcn::Button.new(as_child: Phlex::Shadcn::Calendar.new(today: "2026-03-15", data: { controller: "y" }),
                                    data: { controller: "x y" }).call
    root = Nokogiri::HTML5.fragment(out).at_css("[data-slot=button]")

    assert_equal "shadcn--calendar x y", root["data-controller"]
  end
end

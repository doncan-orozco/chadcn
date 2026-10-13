# frozen_string_literal: true

require "phlex/test_case"

class Phlex::Shadcn::TabsTest < Phlex::Shadcn::TestCase
  Tabs = Phlex::Shadcn::Tabs

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  def fragment(html) = Nokogiri::HTML5.fragment(html)

  def tabs(root: {}, list: {}, trigger: {}, content: {})
    render_view do
      render(Tabs.new(default_value: "a", **root)) do
        render(Tabs::List.new(**list)) do
          render(Tabs::Trigger.new(value: "a", **trigger)) { "One" }
          render(Tabs::Trigger.new(value: "b")) { "Two" }
        end
        render(Tabs::Content.new(value: "a", **content)) { "Body one" }
        render(Tabs::Content.new(value: "b")) { "Body two" }
      end
    end
  end

  test "root renders slot, dir, orientation and merged class" do
    root = fragment(tabs(root: { class: "w-full", id: "t", data: { testid: "x" } })).at_css("[data-slot=tabs]")

    assert_equal "ltr", root["dir"]
    assert_equal "horizontal", root["data-orientation"]
    assert_equal "shadcn--tabs", root["data-controller"]
    assert_equal "t", root["id"]
    assert_equal "x", root["data-testid"]
    assert_includes root["class"], "w-full"
  end

  test "list renders variants" do
    default = fragment(tabs).at_css("[data-slot=tabs-list]")
    line = fragment(tabs(list: { variant: :line })).at_css("[data-slot=tabs-list]")

    assert_equal "tablist", default["role"]
    assert_equal "default", default["data-variant"]
    assert_includes default["class"], "bg-muted"
    assert_equal "line", line["data-variant"]
    assert_includes line["class"], "bg-transparent"
    assert_equal Tabs.list_variants(variant: "line"), line["class"]
  end

  test "triggers and panels are wired by id" do
    doc = fragment(tabs)
    one, two = doc.css("[data-slot=tabs-trigger]")
    panel_one, panel_two = doc.css("[data-slot=tabs-content]")

    assert_equal "true", one["aria-selected"]
    assert_equal "active", one["data-state"]
    assert_equal "false", two["aria-selected"]
    assert_equal "-1", two["tabindex"]
    assert_equal one["aria-controls"], panel_one["id"]
    assert_equal one["id"], panel_one["aria-labelledby"]
    assert_equal two["aria-controls"], panel_two["id"]
    assert_nil panel_one["hidden"]
    assert panel_two.key?("hidden")
    assert_equal "Body one", panel_one.text
    assert_equal [ "template" ], panel_two.element_children.map(&:name)
    assert_includes panel_one["style"], "animation-duration: 0s"
    assert_equal "Body two", panel_two.at_css("template").inner_html.strip
  end

  test "disabled trigger" do
    trigger = fragment(tabs(trigger: { disabled: true, class: "extra" })).at_css("[data-slot=tabs-trigger]")

    assert trigger.key?("disabled")
    assert_equal "", trigger["data-disabled"]
    assert_includes trigger["class"], "extra"
  end

  test "as_child content that is inactive renders only a template" do
    html = render_view do
      render(Tabs.new(default_value: "a")) do
        render(Tabs::Content.new(value: "b", as_child: :section)) { "Body" }
      end
    end
    doc = fragment(html)

    assert_equal [ "template" ], doc.at_css("[data-slot=tabs]").element_children.map(&:name)
    assert_equal "section", doc.at_css("template").element_children.first.name
  end

  test "parts outside Tabs raise" do
    assert_raises(ArgumentError) { render_view { render(Tabs::List.new) } }
  end

  test "dir: local wins, then the provider, then ltr" do
    provided = render_view do
      render(Phlex::Shadcn::Direction::Provider.new(dir: "rtl")) do
        render(Tabs.new) { }
        render(Tabs.new(dir: "ltr")) { }
      end
    end
    rtl, ltr = fragment(provided).css("[data-slot=tabs]")

    assert_equal "rtl", rtl["dir"]
    assert_equal "rtl", rtl["data-shadcn--tabs-dir-value"]
    assert_equal "ltr", ltr["dir"]
    assert_equal "ltr", fragment(render_view { render(Tabs.new) { } }).at_css("[data-slot=tabs]")["dir"]
  end

  test "every DX helper renders like the explicit part" do
    %i[list trigger content].each { |helper| assert_includes Tabs.public_instance_methods, helper }

    helpers = render_view do
      render(Tabs.new(default_value: "a", id: "t")) do |tabs|
        tabs.list(variant: "line") { tabs.trigger(value: "a") { "One" } }
        tabs.content(value: "a") { "Body" }
      end
    end
    explicit = render_view do
      render(Tabs.new(default_value: "a", id: "t")) do
        render(Tabs::List.new(variant: "line")) { render(Tabs::Trigger.new(value: "a")) { "One" } }
        render(Tabs::Content.new(value: "a")) { "Body" }
      end
    end

    assert_equal explicit, helpers
  end
end

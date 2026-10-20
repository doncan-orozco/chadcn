# frozen_string_literal: true

require "test_helper"

class ShadcnParity::TreeRendererTest < ActiveSupport::TestCase
  def render_tree(tree, **opts)
    ApplicationController.new.view_context.render(ShadcnParity::TreeRenderer.new(tree: tree, component: "_harness", **opts))
  end

  def nested_tree
    ShadcnParity::Scenario.find("_harness", "nested").fetch("tree")
  end

  test "$date: and $locale: markers are converted at any depth, other strings stay verbatim like Harness.tsx" do
    renderer = ShadcnParity::TreeRenderer.new(tree: {})
    value = { "a" => "$date:2026-03-15", "b" => [ "$locale:es", { "x" => "$date:2026-03-15", "y" => "$date:2026-1-5" } ], "d" => "$date:2026-03-15x", "e" => "x$date:2026-03-15",
              "f" => "$date:", "g" => "$locale:" }

    assert_equal({ "a" => "2026-03-15", "b" => [ "es", { "x" => "2026-03-15", "y" => "$date:2026-1-5" } ], "d" => "$date:2026-03-15x", "e" => "x$date:2026-03-15",
                   "f" => "$date:", "g" => "$locale:" }, renderer.send(:plain_values, value))
  end

  test "helper mode goes through the yielded root and renders the same HTML" do
    calls = 0
    spy = Module.new do
      define_method(:item) do |**attrs, &block|
        calls += 1
        super(**attrs, &block)
      end
    end
    ShadcnParity::ProbeGroup.prepend(spy)

    assert_equal render_tree(nested_tree), render_tree(nested_tree, dx: "helpers")
    assert_equal 3, calls
  end

  test "raw elements, icons and className mapping" do
    html = render_tree({ "c" => "_div", "props" => { "className" => "p-1", "data-x" => "1" }, "children" => [ "<icon:check> ok" ] })

    assert_includes html, 'class="p-1"'
    assert_includes html, 'data-x="1"'
    assert_includes html, "lucide-check"
    assert_includes html, "ok"
  end

  test "raw elements map React DOM props and value semantics" do
    input = render_tree({ "c" => "_input", "props" => { "defaultValue" => "a", "readOnly" => true, "tabIndex" => -1, "maxLength" => 5,
                                                         "autoComplete" => "off", "disabled" => false, "defaultChecked" => true } })

    assert_includes input, 'value="a"'
    assert_includes input, " readonly"
    assert_includes input, 'tabindex="-1"'
    assert_includes input, 'maxlength="5"'
    assert_includes input, 'autocomplete="off"'
    assert_includes input, " checked"
    assert_no_match(/defaultvalue|disabled/, input)

    label = render_tree({ "c" => "_label", "props" => { "htmlFor" => "x", "className" => "c" } })

    assert_includes label, 'for="x"'
    assert_includes label, 'class="c"'

    textarea = render_tree({ "c" => "_textarea", "props" => { "defaultValue" => "hi" } })

    assert_includes textarea, ">hi</textarea>"
    assert_no_match(/value=/, textarea)

    select = render_tree({ "c" => "_select", "props" => { "defaultValue" => "b" },
                           "children" => [ { "c" => "_option", "props" => { "value" => "a" }, "children" => [ "A" ] },
                                           { "c" => "_option", "props" => { "value" => "b" }, "children" => [ "B" ] } ] })

    assert_match(/<option value="b" selected/, select)
    assert_no_match(/<option value="a" selected/, select)
    assert_no_match(/<select[^>]*value=/, select)
  end

  test "an unknown component raises" do
    assert_raises(ShadcnParity::TreeRenderer::Error) { render_tree({ "c" => "Nope" }) }
  end

  test "scenario lookup rejects traversal and unknown ids" do
    assert_raises(ShadcnParity::Scenario::NotFound) { ShadcnParity::Scenario.find("../x", "a") }
    assert_raises(ShadcnParity::Scenario::NotFound) { ShadcnParity::Scenario.find("_harness", "ghost") }
  end

  test "style objects use CSS property names" do
    style = { "minWidth" => 200, "WebkitLineClamp" => 2, "msTransform" => "none", "--my-Var" => "1", "color" => "red" }
    html = render_tree({ "c" => "_div", "props" => { "style" => style } })

    assert_includes html, "min-width: 200"
    assert_includes html, "-webkit-line-clamp: 2"
    assert_includes html, "-ms-transform: none"
    assert_includes html, "--my-Var: 1"
    assert_includes html, "color: red"
  end

  test "style objects of component props are converted too and merge with a child style" do
    html = render_tree({ "c" => "Button", "props" => { "asChild" => true, "style" => { "minWidth" => 200 } },
                         "children" => [ { "c" => "_a", "props" => { "style" => { "width" => "74px" } } } ] })

    assert_includes html, "min-width: 200"
    assert_includes html, "width: 74px"
  end

  test "a malformed component name raises TreeRenderer::Error" do
    assert_raises(ShadcnParity::TreeRenderer::Error) { render_tree({ "c" => "Bad::Name" }) }
  end

  test "a child that is neither String nor Hash raises TreeRenderer::Error" do
    assert_raises(ShadcnParity::TreeRenderer::Error) { render_tree({ "c" => "_div", "children" => [ 1 ] }) }
  end
end

# frozen_string_literal: true

require "test_helper"

# The chart nodes of a scenario tree in the packaged renderer, the same tree the React Harness.tsx reads (dev/port/specs/chart.md,
# "Oracle driving"). The parity harness reuses this mapping (dev/dummy/test/parity/chart_scope_test.rb runs it through ShadcnParity).
class Chadcn::Catalog::ChartScopeTest < Minitest::Test
  ROWS = [ { "month" => "January", "desktop" => 186 }, { "month" => "February", "desktop" => 305 } ].freeze
  CONFIG = { "desktop" => { "label" => "Desktop", "color" => "red" } }.freeze

  def render_container(*children)
    tree = { "c" => "ChartContainer", "props" => { "id" => "k", "config" => CONFIG }, "children" => children }
    Chadcn::Catalog::TreeRenderer.new(tree: tree, component: "chart").call
  end

  def bar_chart(*children) = { "c" => "_BarChart", "props" => { "data" => ROWS, "margin" => { "left" => 12 } }, "children" => children }

  def x_axis = { "c" => "_XAxis", "props" => { "dataKey" => "month", "tickFormatter" => { "formatter" => "slice", "args" => [ 0, 3 ] } } }
  def bar = { "c" => "_Bar", "props" => { "dataKey" => "desktop", "fill" => "var(--color-desktop)" } }

  def tooltip(content_props = {})
    { "c" => "ChartTooltip", "props" => { "defaultIndex" => 1, "content" => "ChartTooltipContent", "contentProps" => content_props } }
  end

  def test_a_named_slice_formatter_reaches_the_axis_ticks
    assert_includes render_container(bar_chart(x_axis, bar)), ">Jan</tspan>"
  end

  def test_a_tooltip_with_content_renders_the_tooltip_template_target
    assert_includes render_container(bar_chart(tooltip, bar)), 'data-chadcn--chart-target="tooltipTemplate"'
  end

  def test_a_legend_with_content_renders_the_legend_wrapper
    html = render_container(bar_chart({ "c" => "ChartLegend", "props" => { "content" => "ChartLegendContent" } }, bar))

    assert_includes html, "recharts-legend-wrapper"
  end

  def test_content_props_reach_the_content_and_hide_the_label
    shown = render_container(bar_chart(tooltip, bar))
    hidden = render_container(bar_chart(tooltip("hideLabel" => true), bar))

    assert_includes shown, '<div class="font-medium">', "without hideLabel the tooltip label renders"
    refute_includes hidden, '<div class="font-medium">', "hideLabel reaches the content"
  end

  def test_the_svg_a_charts_block_writes_is_drawn_inside_the_svg
    gradient = { "c" => "_linearGradient", "props" => { "id" => "g", "x1" => "0" },
                 "children" => [ { "c" => "_stop", "props" => { "offset" => "5%", "stopColor" => "red" } } ] }
    html = render_container(bar_chart({ "c" => "_defs", "children" => [ gradient ] }, { "c" => "_Bar", "props" => { "dataKey" => "desktop" } }))

    assert_includes html, '<linearGradient id="g" x1="0"><stop offset="5%" stop-color="red"></stop></linearGradient>'
  end

  def payload
    [ { "dataKey" => "desktop", "name" => "desktop", "value" => 305, "color" => "var(--color-desktop)",
        "payload" => { "month" => "February", "desktop" => 305 } } ]
  end

  def tooltip_node(**props) = { "c" => "ChartTooltipContent", "props" => { "active" => true, "payload" => payload, "label" => "February" }.merge(props) }

  def test_a_tooltip_content_node_on_its_own_renders_its_label_and_value
    html = render_container(tooltip_node)

    assert_includes html, "February"
    assert_includes html, "305"
  end

  def test_a_legend_content_node_on_its_own_renders_its_items
    html = render_container({ "c" => "ChartLegendContent",
                              "props" => { "payload" => [ { "value" => "desktop", "dataKey" => "desktop", "type" => "rect", "color" => "red" } ] } })

    assert_includes html, "Desktop"
  end

  def test_active_gates_the_render_and_is_not_an_attribute
    refute_includes render_container(tooltip_node), "active="
  end

  def test_an_inactive_content_node_renders_nothing
    html = render_container({ "c" => "ChartTooltipContent", "props" => { "active" => false, "payload" => [], "label" => "February" } })

    refute_includes html, "February"
  end

  def test_a_pie_its_cell_and_its_label_map_to_the_gems_classes
    data = [ { "browser" => "a", "visitors" => 5 } ]
    pie = { "c" => "_Pie", "props" => { "data" => data, "dataKey" => "visitors", "nameKey" => "browser", "innerRadius" => 20 },
            "children" => [ { "c" => "_Cell", "props" => { "fill" => "red" } },
                            { "c" => "_Label", "props" => { "value" => "Total", "position" => "center" } } ] }
    html = render_container({ "c" => "_PieChart", "children" => [ pie ] })

    assert_includes html, 'fill="red"'
    assert_includes html, ">Total</tspan>"
  end

  def test_an_unknown_underscore_capital_node_still_raises
    assert_raises(Chadcn::Catalog::TreeRenderer::Error) { render_container({ "c" => "_Probe" }) }
  end

  def test_svg_props_keep_react_spelling_except_the_few_react_renames
    gradient = { "c" => "_linearGradient",
                 "props" => { "id" => "g", "gradientTransform" => "rotate(90)", "gradientUnits" => "userSpaceOnUse", "className" => "x" },
                 "children" => [ { "c" => "_stop", "props" => { "offset" => "5%", "stopColor" => "red", "stopOpacity" => 0.8 } } ] }
    html = render_container(bar_chart({ "c" => "_defs", "children" => [ gradient ] }, bar))

    assert_includes html, 'gradientTransform="rotate(90)"'
    assert_includes html, 'gradientUnits="userSpaceOnUse"'
    assert_includes html, 'class="x"'
    assert_includes html, 'stop-opacity="0.8"'
    assert_equal 1, html.scan('stop-color="red"').size
  end

  def test_every_recharts_part_is_a_class_of_the_gem
    Chadcn::Catalog::ChartScope::RECHARTS_PARTS.each { |part| assert_kind_of Class, Chadcn::Chart.const_get(part, false), part }
  end
end

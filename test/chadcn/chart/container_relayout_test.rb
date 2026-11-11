# frozen_string_literal: true

require_relative "polar/polar_helper"

# The resize half of dev/port/specs/chart.md "Behavior", "Resize and re-measure": `Chart::Container relayout_url:`, the values it writes
# for `chadcn--chart`, and `Chart::Container.relayout_options`, which turns the request of the controller back into container keywords.
class Chadcn::Chart::ContainerRelayoutTest < Chadcn::TestCase
  include PolarHelper

  URL = "/reports/visitors/chart"

  def container_node(html) = parse(html).at_css("div[data-slot='chart']")

  def value(node, name) = node["data-chadcn--chart-#{name}-value"]

  def json_value(node, name) = JSON.parse(value(node, name))

  def bar_with_legend(container: {})
    render_chart(container: container) do |chart|
      chart.x_axis(data_key: :month, tick_formatter: SLICE)
      chart.legend
      chart.bar(data_key: :desktop, fill: "var(--color-desktop)")
    end
  end

  def plain_bar(container: {})
    render_chart(container: container) { |chart| chart.bar(data_key: :desktop, fill: "var(--color-desktop)") }
  end

  def chart_markup(html) = parse(html).at_css(".recharts-responsive-container").to_html

  def relayout_options(params, id: "sales") = Chadcn::Chart::Container.relayout_options(params, id: id)

  test "relayout_url: is nil by default and the container writes none of the re-layout values" do
    node = container_node(plain_bar)

    assert_nil Chadcn::Chart::Container.new(config: CONFIG).relayout_url
    assert_nil value(node, "relayout-url")
    assert_nil value(node, "dimension")
    assert_nil value(node, "text-metrics")
  end

  test "with relayout_url: the container writes the URL, the dimension and the metrics the server laid out with" do
    container = { relayout_url: URL, initial_dimension: { width: 480, height: 300 }, text_height: 18, text_char_width: 0.55 }
    node = container_node(plain_bar(container: container))

    assert_equal URL, value(node, "relayout-url")
    assert_equal({ "width" => 480, "height" => 300 }, json_value(node, "dimension"))
    assert_equal({ "textHeight" => 18, "textCharWidth" => 0.55 }, json_value(node, "text-metrics"))
  end

  test "the metrics carry the legend's box height when the chart has a legend" do
    node = container_node(bar_with_legend(container: { relayout_url: URL }))

    assert_equal({ "textHeight" => 16, "textCharWidth" => 0.6, "legendHeight" => 28 }, json_value(node, "text-metrics"))
  end

  test "the server render of the chart is the same with and without relayout_url:" do
    assert_equal chart_markup(bar_with_legend), chart_markup(bar_with_legend(container: { relayout_url: URL }))
    assert_equal chart_markup(render_pie), chart_markup(render_pie(container: { relayout_url: URL }))
  end

  test "relayout_url: must be a non-empty String" do
    [ 42, "", " ", :url ].each do |url|
      error = assert_raises(ArgumentError) { Chadcn::Chart::Container.new(config: CONFIG, relayout_url: url) }
      assert_includes error.message, "relayout_url:"
    end
  end

  test "relayout_options returns the container keywords of the request for that chart" do
    params = { "chart" => { "id" => "sales", "width" => "640", "height" => "400", "text_height" => "18", "text_char_width" => "0.5622" } }

    assert_equal({ initial_dimension: { width: 640, height: 400 }, text_height: 18, text_char_width: 0.5622 }, relayout_options(params))
  end

  test "relayout_options reads symbol keys, numbers and a Symbol id" do
    params = { chart: { id: "sales", width: 512.5, height: 300 } }

    assert_equal({ initial_dimension: { width: 512.5, height: 300 } }, relayout_options(params, id: :sales))
  end

  test "relayout_options reads params with [] only, like unpermitted ActionController::Parameters" do
    params = Class.new do
      def initialize(hash) = @hash = hash
      def [](key) = @hash[key.to_s].then { |nested| nested.is_a?(Hash) ? self.class.new(nested) : nested }
    end.new("chart" => { "id" => "sales", "width" => "640", "height" => "400" })

    assert_equal({ initial_dimension: { width: 640, height: 400 } }, relayout_options(params))
  end

  test "relayout_options is empty for another chart, no chart parameters, or params that are not a Hash" do
    assert_equal({}, relayout_options({ "chart" => { "id" => "other", "width" => "640", "height" => "400" } }))
    assert_equal({}, relayout_options({}))
    assert_equal({}, relayout_options({ "chart" => "640" }))
    assert_equal({}, relayout_options(nil))
  end

  test "relayout_options drops a value that is not a positive finite number within its bound" do
    base = { "id" => "sales", "width" => "640", "height" => "400" }

    [
      { "width" => "0" }, { "width" => "-5" }, { "width" => "4097" }, { "height" => "abc" }, { "height" => "Infinity" }, { "width" => "1e400" },
      { "width" => "" }, { "width" => [ "640" ] }, { "height" => "0x20" }
    ].each { |bad| assert_equal({}, relayout_options({ "chart" => base.merge(bad) }), bad.inspect) }

    bounds = { "text_height" => "257", "text_char_width" => "4.01" }

    assert_equal({ initial_dimension: { width: 640, height: 400 } }, relayout_options({ "chart" => base.merge(bounds) }))
    edges = { "width" => "4096", "height" => "4096", "text_height" => "256", "text_char_width" => "4" }

    assert_equal({ initial_dimension: { width: 4096, height: 4096 }, text_height: 256, text_char_width: 4 },
                 relayout_options({ "chart" => base.merge(edges) }))
  end

  test "relayout_options needs both width and height for a dimension, and ignores legend_height until the container takes it" do
    params = { "chart" => { "id" => "sales", "width" => "640", "text_height" => "14", "legend_height" => "26" } }

    assert_equal({ text_height: 14 }, relayout_options(params))
  end

  # The six chart roots re-lay themselves out at the requested size: what the host's answer to the request renders.
  {
    "BarChart" => -> { render_chart(container: relayout_container) { |chart| chart.bar(data_key: :desktop) } },
    "LineChart" => -> { render_chart(Chadcn::Chart::LineChart, container: relayout_container) { |chart| chart.line(data_key: :desktop) } },
    "AreaChart" => -> { render_chart(Chadcn::Chart::AreaChart, container: relayout_container) { |chart| chart.area(data_key: :desktop) } },
    "PieChart" => -> { render_pie(container: relayout_container) },
    "RadarChart" => -> { render_radar(container: relayout_container) { |chart| chart.radar(data_key: :desktop) } },
    "RadialBarChart" => -> { render_radial_bar(container: relayout_container) { |chart| chart.radial_bar(data_key: :visitors) } }
  }.each do |name, draw|
    test "a #{name} laid out from the request options is drawn at the requested size and says so in its dimension" do
      doc = parse(instance_exec(&draw))

      assert_includes doc.at_css(".recharts-wrapper")["style"], "width: 640px; height: 400px;"
      assert_equal "0 0 640 400", doc.at_css("svg.recharts-surface")["viewBox"]
      assert_equal({ "width" => 640, "height" => 400 }, json_value(container_node(doc.to_html), "dimension"))
    end
  end

  private

  def relayout_container
    request = { "chart" => { "id" => "t", "width" => "640", "height" => "400", "text_height" => "16", "text_char_width" => "0.6" } }
    { id: "t", relayout_url: URL, **Chadcn::Chart::Container.relayout_options(request, id: "t") }
  end
end

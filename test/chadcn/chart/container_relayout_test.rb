# frozen_string_literal: true

require_relative "polar/polar_helper"

# dev/port/specs/chart.md "Behavior", "Resize and re-measure": `Chart::Container relayout_url:`, the values it writes for `chadcn--chart`,
# `Chart::Container.relayout_options`, which turns the request of the controller back into container keywords (item #107), and the
# measured `legend_height:` of the re-measure (item #108).
class Chadcn::Chart::ContainerRelayoutTest < Chadcn::TestCase
  include PolarHelper

  URL = "/reports/visitors/chart"

  def container_node(html) = parse(html).at_css("div[data-slot='chart']")

  def chart_value(node, name) = node["data-chadcn--chart-#{name}-value"]

  def json_value(node, name) = JSON.parse(chart_value(node, name))

  def bar_with_legend(container: {}, **legend)
    render_chart(container: container) do |chart|
      chart.x_axis(data_key: :month, tick_formatter: SLICE)
      chart.legend(**legend)
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
    assert_nil chart_value(node, "relayout-url")
    assert_nil chart_value(node, "dimension")
    assert_nil chart_value(node, "text-metrics")
  end

  test "with relayout_url: the container writes the URL, the dimension and the metrics the server laid out with" do
    container = { relayout_url: URL, initial_dimension: { width: 480, height: 300 }, text_height: 18, text_char_width: 0.55 }
    node = container_node(plain_bar(container: container))

    assert_equal URL, chart_value(node, "relayout-url")
    assert_equal({ "width" => 480, "height" => 300 }, json_value(node, "dimension"))
    assert_equal({ "textHeight" => 18, "textCharWidth" => 0.55 }, json_value(node, "text-metrics"))
  end

  test "the metrics carry the legend's box height when the chart has a legend" do
    node = container_node(bar_with_legend(container: { relayout_url: URL }))

    assert_equal({ "textHeight" => 16, "textCharWidth" => 0.6, "legendHeight" => 28 }, json_value(node, "text-metrics"))
  end

  test "the Legend's own legend_height: reaches legendHeight" do
    node = container_node(bar_with_legend(container: { relayout_url: URL }, legend_height: 40))

    assert_equal 40, json_value(node, "text-metrics")["legendHeight"]
  end

  test "with only relayout_url: the dimension is 320x200 and the metrics the defaults" do
    node = container_node(plain_bar(container: { relayout_url: URL }))

    assert_equal({ "width" => 320, "height" => 200 }, json_value(node, "dimension"))
    assert_equal({ "textHeight" => 16, "textCharWidth" => 0.6 }, json_value(node, "text-metrics"))
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

  test "relayout_options reads params with key? and [] only, like unpermitted ActionController::Parameters" do
    params = Class.new do
      def initialize(hash) = @hash = hash
      def key?(key) = @hash.key?(key.to_s)
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

  test "relayout_options is empty for a blank id, even when the request has no chart[id]" do
    request = { "chart" => { "width" => "640", "height" => "400" } }

    assert_equal({}, relayout_options(request, id: ""))
    assert_equal({}, relayout_options(request, id: nil))
    assert_equal({}, relayout_options({ "chart" => { "id" => "", "width" => "640", "height" => "400" } }, id: ""))
  end

  test "relayout_options is empty when chart is a String, an Array or a Proc" do
    [ "640", [ "sales" ], -> { "sales" } ].each { |chart| assert_equal({}, relayout_options({ "chart" => chart }), chart.inspect) }
  end

  test "the server and the browser share one size bound" do
    primitive = File.read(File.expand_path("../../../app/javascript/chadcn/primitives/chart_relayout.js", __dir__))

    assert_includes primitive, "export const RELAYOUT_MAX_SIZE = #{Chadcn::Chart::Container::RELAYOUT_MAX_SIZE}"
  end

  test "relayout_options drops a value that is not a positive finite number within its bound" do
    base = { "id" => "sales", "width" => "640", "height" => "400" }

    [
      { "width" => "0" }, { "width" => "-5" }, { "width" => "4097" }, { "height" => "abc" }, { "height" => "Infinity" }, { "width" => "1e400" },
      { "width" => "" }, { "width" => [ "640" ] }, { "height" => "0x20" }
    ].each { |invalid_parameter| assert_equal({}, relayout_options({ "chart" => base.merge(invalid_parameter) }), invalid_parameter.inspect) }

    bounds = { "text_height" => "257", "text_char_width" => "4.01", "legend_height" => "256.5" }

    assert_equal({ initial_dimension: { width: 640, height: 400 } }, relayout_options({ "chart" => base.merge(bounds) }))
    edges = { "width" => "4096", "height" => "4096", "text_height" => "256", "text_char_width" => "4" }

    assert_equal({ initial_dimension: { width: 4096, height: 4096 }, text_height: 256, text_char_width: 4 },
                 relayout_options({ "chart" => base.merge(edges) }))
  end

  test "relayout_options needs both width and height for a dimension" do
    params = { "chart" => { "id" => "sales", "width" => "640", "text_height" => "14", "legend_height" => "26" } }

    assert_equal({ text_height: 14, legend_height: 26 }, relayout_options(params))
  end

  test "relayout_options reads legend_height within its bound" do
    base = { "id" => "sales" }

    assert_equal({ legend_height: 25.5 }, relayout_options({ "chart" => base.merge("legend_height" => "25.5") }))
    assert_equal({ legend_height: 256 }, relayout_options({ "chart" => base.merge("legend_height" => "256") }))
    assert_equal({}, relayout_options({ "chart" => base.merge("legend_height" => "257") }))
    assert_equal({}, relayout_options({ "chart" => base.merge("legend_height" => "0") }))
  end

  # The re-measure half (item #108): the measured legend height reaches the layout through the container.
  test "legend_height: is nil by default and must be a positive finite number" do
    assert_nil Chadcn::Chart::Container.new(config: CONFIG).legend_height
    assert_equal 26, Chadcn::Chart::Container.new(config: CONFIG, legend_height: 26).legend_height
    [ 0, -1, Float::INFINITY, "26" ].each do |height|
      error = assert_raises(ArgumentError) { Chadcn::Chart::Container.new(config: CONFIG, legend_height: height) }
      assert_includes error.message, "legend_height:"
    end
  end

  test "the container's legend_height: lays the chart out like the Legend's own legend_height:" do
    measured = chart_markup(bar_with_legend(container: { legend_height: 26 }))

    assert_equal chart_markup(bar_with_legend(legend_height: 26)), measured
    refute_equal chart_markup(bar_with_legend), measured
  end

  test "the container's legend_height: wins over the Legend's assumption, a numeric Legend height: wins over both" do
    assert_equal chart_markup(bar_with_legend(legend_height: 26)), chart_markup(bar_with_legend(container: { legend_height: 26 }, legend_height: 40))
    assert_equal chart_markup(bar_with_legend(height: 30)), chart_markup(bar_with_legend(container: { legend_height: 26 }, height: 30))
  end

  test "the container's legend_height: is the legendHeight of the metrics" do
    node = container_node(bar_with_legend(container: { relayout_url: URL, legend_height: 26 }))

    assert_equal({ "textHeight" => 16, "textCharWidth" => 0.6, "legendHeight" => 26 }, json_value(node, "text-metrics"))
  end

  test "the container's legend_height: changes nothing on a chart without a legend" do
    assert_equal chart_markup(plain_bar), chart_markup(plain_bar(container: { legend_height: 26 }))
    assert_nil json_value(container_node(plain_bar(container: { relayout_url: URL, legend_height: 26 })), "text-metrics")["legendHeight"]
  end

  test "a polar chart takes the container's legend_height: like the Legend's own" do
    legend = ->(height = nil) { ->(chart) { chart.legend(**{ legend_height: height }.compact) } }

    assert_equal chart_markup(render_pie(around: legend.call(26))), chart_markup(render_pie(container: { legend_height: 26 }, around: legend.call))
    refute_equal chart_markup(render_pie(around: legend.call)), chart_markup(render_pie(container: { legend_height: 26 }, around: legend.call))
  end

  test "the measured metrics from the request reach the layout: a request is a container keyword set" do
    request = { "chart" => { "id" => "t", "width" => "320", "height" => "200", "text_height" => "14", "text_char_width" => "0.55", "legend_height" => "26" } }
    options = Chadcn::Chart::Container.relayout_options(request, id: "t")
    node = container_node(bar_with_legend(container: { id: "t", relayout_url: URL, **options }))

    assert_equal({ "textHeight" => 14, "textCharWidth" => 0.55, "legendHeight" => 26 }, json_value(node, "text-metrics"))
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

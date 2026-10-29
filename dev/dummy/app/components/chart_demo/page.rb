# frozen_string_literal: true

# A page with Turbo Drive ON and one chart of a family (bar, line, area, pie, radar, radial) for test/javascript/chart.test.mjs. `bar` is the plain
# hover chart, `line` has a `default_index`, `area` follows clicks (`trigger: :click`); `pie`, `radar` and `radial` (a radial bar) are polar
# charts with a `default_index` (the controller keeps that tooltip and nothing moves it). A link leads to a second page and back, to leave the
# page and have Turbo cache it. No scenario JSON, no React twin.
class ChartDemo::Page < Phlex::HTML
  include Phlex::Rails::Helpers::StylesheetLinkTag
  include Phlex::Rails::Helpers::JavascriptImportmapTags

  FAMILIES = %w[bar line area pie radar radial other].freeze

  ROWS = [
    { month: "January", desktop: 186, mobile: 80 },
    { month: "February", desktop: 305, mobile: 200 },
    { month: "March", desktop: 237, mobile: 120 },
    { month: "April", desktop: 73, mobile: 190 },
    { month: "May", desktop: 209, mobile: 130 },
    { month: "June", desktop: 214, mobile: 140 }
  ].freeze
  BROWSERS = [
    { browser: "chrome", visitors: 275, fill: "var(--color-chrome)" },
    { browser: "safari", visitors: 200, fill: "var(--color-safari)" },
    { browser: "firefox", visitors: 187, fill: "var(--color-firefox)" },
    { browser: "edge", visitors: 173, fill: "var(--color-edge)" },
    { browser: "other", visitors: 90, fill: "var(--color-other)" }
  ].freeze
  CONFIG = { desktop: { label: "Desktop", color: "var(--chart-1)" }, mobile: { label: "Mobile", color: "var(--chart-2)" } }.freeze
  BROWSER_CONFIG = {
    visitors: { label: "Visitors" }, chrome: { label: "Chrome", color: "var(--chart-1)" }, safari: { label: "Safari", color: "var(--chart-2)" },
    firefox: { label: "Firefox", color: "var(--chart-3)" }, edge: { label: "Edge", color: "var(--chart-4)" }, other: { label: "Other", color: "var(--chart-5)" }
  }.freeze

  def initialize(family:)
    @family = family
    super()
  end

  def view_template
    doctype
    html(lang: "en") do
      head do
        meta(charset: "utf-8")
        title { "chart demo #{@family}" }
        stylesheet_link_tag("tailwind")
        javascript_importmap_tags
      end
      body(class: "bg-background text-foreground") do
        div(class: "p-8 space-y-4", id: "chart-demo-#{@family}") do
          @family == "other" ? other_page : chart_page
        end
      end
    end
  end

  private

  def chart_page
    a(href: "/design-system/chart-demo/other", id: "to-other") { "Other page" }
    render Chadcn::Chart::Container.new(config: %w[pie radial].include?(@family) ? BROWSER_CONFIG : CONFIG, id: "demo", class: "aspect-auto h-[200px] w-[320px]") do
      send(@family)
    end
  end

  def other_page
    h1 { "Other page" }
    a(href: "/design-system/chart-demo/bar", id: "to-bar") { "Back to the bar chart" }
  end

  def content = Chadcn::Chart::Tooltip::Content.new

  def bar
    render Chadcn::Chart::BarChart.new(data: ROWS) do |chart|
      chart.x_axis(data_key: :month, tick_line: false, axis_line: false, tick_margin: 10, tick_formatter: { slice: [ 0, 3 ] })
      chart.bar(data_key: :desktop, fill: "var(--color-desktop)", radius: 4)
      chart.bar(data_key: :mobile, fill: "var(--color-mobile)", radius: 4)
      chart.tooltip(content: content)
    end
  end

  def line
    render Chadcn::Chart::LineChart.new(data: ROWS) do |chart|
      chart.x_axis(data_key: :month, tick_line: false, axis_line: false, tick_margin: 8, tick_formatter: { slice: [ 0, 3 ] })
      chart.line(data_key: :desktop, stroke: "var(--color-desktop)", type: :natural)
      chart.tooltip(default_index: 2, content: content)
    end
  end

  def area
    render Chadcn::Chart::AreaChart.new(data: ROWS) do |chart|
      chart.x_axis(data_key: :month, tick_line: false, axis_line: false, tick_margin: 8, tick_formatter: { slice: [ 0, 3 ] })
      chart.area(data_key: :desktop, fill: "var(--color-desktop)", stroke: "var(--color-desktop)", type: :natural)
      chart.tooltip(trigger: :click, content: content)
    end
  end

  def pie
    render Chadcn::Chart::PieChart.new(data: []) do |chart|
      chart.tooltip(default_index: 1, content: content)
      chart.pie(data: BROWSERS, data_key: :visitors, name_key: :browser)
    end
  end

  def radar
    render Chadcn::Chart::RadarChart.new(data: ROWS) do |chart|
      chart.polar_angle_axis(data_key: :month)
      chart.tooltip(default_index: 1, content: content)
      chart.radar(data_key: :desktop, fill: "var(--color-desktop)")
    end
  end

  def radial
    render Chadcn::Chart::RadialBarChart.new(data: BROWSERS, inner_radius: 30, outer_radius: 110) do |chart|
      chart.tooltip(default_index: 1, content: content)
      chart.radial_bar(data_key: :visitors, background: true)
    end
  end
end

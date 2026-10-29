# frozen_string_literal: true

# A page with Turbo Drive ON and one chart of a family (bar, line, area) for test/javascript/chart.test.mjs. `bar` is the plain hover
# chart, `line` has a `default_index`, `area` follows clicks (`trigger: :click`). A link leads to a second page and back, to leave the
# page and have Turbo cache it. No scenario JSON, no React twin.
class ChartDemo::Page < Phlex::HTML
  include Phlex::Rails::Helpers::StylesheetLinkTag
  include Phlex::Rails::Helpers::JavascriptImportmapTags

  FAMILIES = %w[bar line area other].freeze

  ROWS = [
    { month: "January", desktop: 186, mobile: 80 },
    { month: "February", desktop: 305, mobile: 200 },
    { month: "March", desktop: 237, mobile: 120 },
    { month: "April", desktop: 73, mobile: 190 },
    { month: "May", desktop: 209, mobile: 130 },
    { month: "June", desktop: 214, mobile: 140 }
  ].freeze
  CONFIG = { desktop: { label: "Desktop", color: "var(--chart-1)" }, mobile: { label: "Mobile", color: "var(--chart-2)" } }.freeze

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
    render Chadcn::Chart::Container.new(config: CONFIG, id: "demo", class: "aspect-auto h-[200px] w-[320px]") do
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
end

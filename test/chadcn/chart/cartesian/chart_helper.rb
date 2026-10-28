# frozen_string_literal: true

require "chadcn/test_case"

# What the chart tests share: the rows of the shadcn chart examples, a render of a chart inside a container, and a parsed document.
module ChartHelper
  ROWS = [
    { month: "January", desktop: 186, mobile: 80 },
    { month: "February", desktop: 305, mobile: 200 },
    { month: "March", desktop: 237, mobile: 120 },
    { month: "April", desktop: 73, mobile: 190 },
    { month: "May", desktop: 209, mobile: 130 },
    { month: "June", desktop: 214, mobile: 140 }
  ].freeze
  CONFIG = { desktop: { label: "Desktop", color: "var(--chart-1)" }, mobile: { label: "Mobile", color: "var(--chart-2)" } }.freeze
  SLICE = { slice: [ 0, 3 ] }.freeze

  # Renders `chart_class` with `props` and the block (the chart's block receives the chart) inside a container.
  def render_chart(chart_class = Chadcn::Chart::BarChart, container: {}, **props, &block)
    options = { config: CONFIG, id: "t" }.merge(container)
    props = { data: ROWS }.merge(props)
    Class.new(Phlex::HTML) do
      define_method(:view_template) { render(Chadcn::Chart::Container.new(**options)) { render(chart_class.new(**props), &block) } }
    end.new.call
  end

  # Renders a chart with no container around it.
  def render_bare_chart(chart_class = Chadcn::Chart::BarChart, **props, &block)
    props = { data: ROWS }.merge(props)
    Class.new(Phlex::HTML) { define_method(:view_template) { render(chart_class.new(**props), &block) } }.new.call
  end

  def parse(html) = Nokogiri::HTML5.fragment(html)

  def layer(doc, z) = doc.at_css("g.recharts-zIndex-layer_#{z}")

  def number(node, name) = node[name].to_f

  def values(node, *names) = names.map { |name| node[name] }

  def bars(doc, index = 0) = doc.css("g.recharts-bar")[index].css("path.recharts-rectangle")
end

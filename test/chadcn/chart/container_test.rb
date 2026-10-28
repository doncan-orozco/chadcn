# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::ContainerTest < Chadcn::TestCase
  CONFIG = { desktop: { label: "Desktop", color: "var(--chart-1)" }, mobile: { theme: { light: "#000", dark: "#fff" } } }.freeze

  def render_container(**props, &block)
    props = { config: CONFIG, id: "a" }.merge(props)
    Class.new(Phlex::HTML) { define_method(:view_template) { render(Chadcn::Chart::Container.new(**props), &block) } }.new.call
  end

  def root(html) = Nokogiri::HTML.fragment(html).at_css("div[data-slot='chart']")

  test "renders the chart div with the slot, the id and the oracle classes" do
    node = root(render_container)

    assert_equal "chart-a", node["data-chart"]
    assert_includes node["class"].split, "aspect-video"
    assert_includes node["class"], "[&_.recharts-cartesian-axis-tick_text]:fill-muted-foreground"
    assert_includes node["class"], "[&_.recharts-surface]:outline-hidden"
  end

  test "renders one style tag with both selectors and the two variables" do
    html = render_container
    css = Nokogiri::HTML.fragment(html).css("style")

    assert_equal 1, css.length
    assert_includes css.text, " [data-chart=chart-a] {"
    assert_includes css.text, ".dark [data-chart=chart-a] {"
    assert_includes css.text, "--color-desktop: var(--chart-1);"
    assert_includes css.text, "--color-mobile: #000;"
    assert_includes css.text, "--color-mobile: #fff;"
  end

  test "a config without colors renders no style tag" do
    assert_empty Nokogiri::HTML.fragment(render_container(config: { desktop: { label: "Desktop" } })).css("style")
  end

  test "wraps the block in the responsive container shell and yields itself" do
    yielded = nil
    html = render_container { |container| yielded = container }
    shell = root(html).at_css("> .recharts-responsive-container")

    assert_equal "width: 100%; height: 100%; min-width: 0px;", shell["style"]
    assert_equal "width: 0px; height: 0px; overflow: visible;", shell.at_css("> div")["style"]
    assert_instance_of Chadcn::Chart::Container, yielded
    assert_equal "chart-a", yielded.chart_id
    assert_equal({ width: 320, height: 200 }, yielded.initial_dimension)
  end

  test "class is merged last and attributes land on the div" do
    node = root(render_container(class: "h-[250px] aspect-auto", data: { controller: "chadcn--chart" }, aria: { label: "Visitors" }))

    assert_includes node["class"].split, "h-[250px]"
    assert_not_includes node["class"].split, "aspect-video"
    assert_equal "chadcn--chart", node["data-controller"]
    assert_equal "Visitors", node["aria-label"]
  end

  test "a random id is used when none is given and differs between renders" do
    ids = Array.new(2) { root(Chadcn::Chart::Container.new(config: CONFIG).call)["data-chart"] }

    assert_match(/\Achart-[a-z0-9]{8}\z/, ids.first)
    assert_not_equal ids.first, ids.last
  end

  test "the container is current while the block renders and gone after" do
    view = Class.new(Phlex::HTML) do
      define_method(:view_template) do
        render(Chadcn::Chart::Container.new(config: CONFIG, id: "a")) do |container|
          plain "inside:#{Chadcn::Chart::Container.current(context).equal?(container)}"
        end
        plain " after:#{Chadcn::Chart::Container.current(context).inspect}"
      end
    end

    assert_includes view.new.call, "inside:true"
    assert_includes view.new.call, "after:nil"
  end

  test "an invalid initial dimension or id raises" do
    assert_raises(ArgumentError) { Chadcn::Chart::Container.new(config: CONFIG, initial_dimension: { width: 0, height: 10 }) }
    assert_raises(ArgumentError) { Chadcn::Chart::Container.new(config: CONFIG, initial_dimension: { width: 10 }) }
    assert_raises(ArgumentError) { Chadcn::Chart::Container.new(config: CONFIG, id: "a b") }
    assert_equal({ width: 100, height: 50 },
                 Chadcn::Chart::Container.new(config: CONFIG, initial_dimension: { "width" => 100, "height" => 50 }).initial_dimension)
  end
end

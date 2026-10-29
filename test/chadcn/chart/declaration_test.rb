# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::DeclarationTest < Chadcn::TestCase
  include ChartHelper

  test "a declaration renders nothing where it is written" do
    html = render_chart do |chart|
      chart.bar(data_key: :desktop)
    end
    surface = parse(html).at_css("svg.recharts-surface")

    assert_equal "", surface.at_css("> g.recharts-zIndex-layer_100").inner_html
    assert_equal 12, surface.css("> g").size
  end

  test "every subclass gets a helper on Declarations, with the reserved-name check" do
    Chadcn::Chart::BarChart.new # building a chart loads the whole family of declarations
    names = Chadcn::Chart::Declaration.subclasses.reject { |klass| klass.name.nil? }.map { |klass| Chadcn::Chart::Declarations.helper_name(klass.name) }

    expected = %i[area bar cartesian_grid cell label label_list legend line pie polar_angle_axis polar_grid polar_radius_axis radar radial_bar
                  reference_line tooltip x_axis y_axis]

    assert_equal expected.sort, names.sort
    names.each { |name| assert Chadcn::Chart::Declarations.public_method_defined?(name), "missing helper ##{name}" }
  end

  test "a declaration named like a Phlex method is refused" do
    stub = Class.new { def self.name = "Chadcn::Chart::Render" }
    error = assert_raises(ArgumentError) { Chadcn::Chart::Declaration.inherited(stub) }

    assert_match(%r{would override a Ruby/Phlex API method}, error.message)
  end

  test "an anonymous subclass defines no helper" do
    before = Chadcn::Chart::Declarations.public_instance_methods(false)
    Class.new(Chadcn::Chart::Declaration)

    assert_equal before, Chadcn::Chart::Declarations.public_instance_methods(false)
  end

  test "helper_name turns the class name into the snake_case of the helper" do
    assert_equal :x_axis, Chadcn::Chart::Declarations.helper_name("Chadcn::Chart::XAxis")
    assert_equal :label_list, Chadcn::Chart::Declarations.helper_name("LabelList")
    assert_equal :radial_bar, Chadcn::Chart::Declarations.helper_name("A::RadialBar")
  end
end

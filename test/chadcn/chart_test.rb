# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::ChartTest < Chadcn::TestCase
  CONFIG = { desktop: { label: "Desktop", color: "var(--chart-1)" } }.freeze

  def render_view(&block)
    Class.new(Phlex::HTML) { define_method(:view_template, &block) }.new.call
  end

  test "the root yields itself and renders nothing of its own" do
    yielded = nil
    html = Chadcn::Chart.new.call { |chart| yielded = chart }

    assert_instance_of Chadcn::Chart, yielded
    assert_equal "", html
  end

  test "the root has one generated helper for each nested part and none for the config" do
    parts = Chadcn::Chart.constants(false).map { |name| Chadcn::Chart.const_get(name, false) }
                         .select { |part| part.is_a?(Class) && part < Chadcn::Base }
    helpers = parts.map { |part| part.name.split("::").last.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.to_sym }

    assert_includes helpers, :container
    assert_empty(helpers.reject { |helper| Chadcn::Chart.public_method_defined?(helper, false) })
    assert_not Chadcn::Chart.public_method_defined?(:config, false)
  end

  test "the generated helpers render the same HTML as the explicit classes" do
    explicit = render_view do
      render(Chadcn::Chart::Container.new(config: CONFIG, id: "a")) do
        render Chadcn::Chart::Style.new(id: "b", config: CONFIG)
      end
    end
    helpers = render_view do
      render(Chadcn::Chart.new) do |chart|
        chart.container(config: CONFIG, id: "a") { chart.style(id: "b", config: CONFIG) }
      end
    end

    assert_equal explicit, helpers
  end

  test "the content classes yield their helper on the tooltip and the legend, not on the root" do
    assert Chadcn::Chart::Tooltip.public_method_defined?(:content, false)
    assert Chadcn::Chart::Legend.public_method_defined?(:content, false)
    assert_not Chadcn::Chart.public_method_defined?(:tooltip_content)
    assert_not Chadcn::Chart.public_method_defined?(:legend_content)
  end

  test "a style that cannot be written safely raises instead of reaching the stylesheet" do
    assert_raises(ArgumentError) { Chadcn::Chart::Config.new(desktop: { color: "red;}</style><script>" }) }
    assert_raises(ArgumentError) { Chadcn::Chart::Config.new("a b" => { color: "red" }) }
    assert_raises(ArgumentError) { Chadcn::Chart::Style.new(id: "x]{", config: CONFIG) }
    assert_raises(ArgumentError) { Chadcn::Chart::Container.new(config: CONFIG, id: "x]{") }
  end

  test "the parts load in a fresh process without eager loading" do
    script = <<~RUBY
      require "chadcn"
      puts Chadcn::Chart::Container.new(config: { a: { color: "red" } }, id: "z").call.include?('data-chart="chart-z"')
      puts Chadcn::Chart::Tooltip::Content.instance_method(:view_template).owner
      puts Chadcn::Chart::Legend::Content.name
      puts Chadcn::Chart::Scale.class
      puts Chadcn::Chart.public_method_defined?(:scale)
    RUBY
    output = IO.popen([ RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__), "-e", script ], err: %i[child out], &:read)

    assert_equal [ "true", "Chadcn::Chart::Tooltip::Content", "Chadcn::Chart::Legend::Content", "Module", "false" ], output.lines.map(&:strip).last(5), output
  end

  test "every chart class offers one generated helper per declaration, equal to the explicit class" do
    Chadcn::Chart::BarChart.new # building a chart loads the declarations
    helpers = Chadcn::Chart::Declaration.subclasses.map { |part| Chadcn::Chart::Declarations.helper_name(part.name) }

    assert_equal 12, helpers.size
    [ Chadcn::Chart::BarChart, Chadcn::Chart::LineChart, Chadcn::Chart::AreaChart ].each do |chart_class|
      assert_empty(helpers.reject { |helper| chart_class.public_method_defined?(helper) }, chart_class.name)
    end
    rows = [ { a: 1 }, { a: 2 } ]
    explicit = render_view { render(Chadcn::Chart::BarChart.new(data: rows)) { |chart| chart.render Chadcn::Chart::Bar.new(data_key: :a) } }
    generated = render_view { render(Chadcn::Chart::BarChart.new(data: rows)) { |chart| chart.bar(data_key: :a) } }

    assert_equal explicit, generated
  end

  test "in a fresh process with the lazy loader the declaration helpers exist before any declaration constant is referenced" do
    script = <<~RUBY
      require "chadcn"
      rows = [ { a: 1 }, { a: 2 } ]
      helper = Class.new(Phlex::HTML) { define_method(:view_template) { render(Chadcn::Chart::BarChart.new(data: rows)) { |chart| chart.bar(data_key: :a) } } }.new.call
      explicit = Class.new(Phlex::HTML) { define_method(:view_template) { render(Chadcn::Chart::BarChart.new(data: rows)) { |chart| chart.render Chadcn::Chart::Bar.new(data_key: :a) } } }.new.call
      puts helper == explicit
      puts helper.include?("recharts-bar-rectangle")
    RUBY
    output = IO.popen([ RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__), "-e", script ], err: %i[child out], &:read)

    assert_equal %w[true true], output.lines.map(&:strip).last(2), output
  end

  test "in a fresh process a declaration named like a Phlex method is refused" do
    script = <<~RUBY
      require "chadcn"
      module Custom; end
      begin
        class Custom::Render < Chadcn::Chart::Declaration; end
        puts "no error"
      rescue ArgumentError => error
        puts error.message
      end
    RUBY
    output = IO.popen([ RbConfig.ruby, "-I", File.expand_path("../../lib", __dir__), "-e", script ], err: %i[child out], &:read)

    assert_equal "helper #render (from Custom::Render) would override a Ruby/Phlex API method", output.lines.map(&:strip).last
  end

  test "the root renders without a block" do
    assert_equal "", Chadcn::Chart.new.call
  end

  test "the tooltip and legend helpers render the same HTML as the explicit classes" do
    rows = [ { a: 1 }, { a: 2 } ]
    contents = { tooltip: Chadcn::Chart::Tooltip::Content.new, legend: Chadcn::Chart::Legend::Content.new }
    explicit = render_view do
      render(Chadcn::Chart::Container.new(config: { a: { label: "A", color: "red" } }, id: "k")) do
        render(Chadcn::Chart::BarChart.new(data: rows)) do |chart|
          chart.render Chadcn::Chart::Tooltip.new(default_index: 1, content: contents[:tooltip])
          chart.render Chadcn::Chart::Legend.new(vertical_align: :top, content: contents[:legend])
          chart.bar(data_key: :a)
        end
      end
    end
    helpers = render_view do
      render(Chadcn::Chart::Container.new(config: { a: { label: "A", color: "red" } }, id: "k")) do
        render(Chadcn::Chart::BarChart.new(data: rows)) do |chart|
          chart.tooltip(default_index: 1, content: contents[:tooltip])
          chart.legend(vertical_align: :top, content: contents[:legend])
          chart.bar(data_key: :a)
        end
      end
    end

    assert_equal explicit, helpers
  end

  test "Base.const_added skips a namespace autoloaded from a directory: no helper, no load" do
    require "tmpdir"
    root = Class.new(Chadcn::Base)
    Dir.mktmpdir do |dir|
      namespace = File.join(dir, "scale")
      Dir.mkdir(namespace)
      root.autoload(:Scale, namespace)

      assert_not root.public_method_defined?(:scale, false)
      assert_equal namespace, root.autoload?(:Scale, false)
    end
  end
end

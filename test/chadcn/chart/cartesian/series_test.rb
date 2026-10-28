# frozen_string_literal: true

require_relative "chart_helper"

class Chadcn::Chart::Cartesian::SeriesTest < Chadcn::TestCase
  include ChartHelper

  test "a series knows its kind and keeps its options frozen" do
    assert_equal(%i[bar line area], [ Chadcn::Chart::Bar, Chadcn::Chart::Line, Chadcn::Chart::Area ].map { |klass| klass.new(data_key: :a).kind })
    assert_predicate Chadcn::Chart::Bar.new(data_key: :a).options, :frozen?
  end

  test "label lists and cells written in the block belong to the series, in order" do
    bar = Chadcn::Chart::Bar.new(data_key: :desktop)
    render_chart { |chart| chart.bar(data_key: :desktop) { |inner| inner.cell(fill: "red") } }
    bar.declare(first = Chadcn::Chart::LabelList.new)
    bar.declare(cell = Chadcn::Chart::Cell.new(fill: "blue"))

    assert_equal [ first ], bar.label_lists
    assert_equal [ cell ], bar.cells
  end

  test "label: true or a Hash is an implicit label list, written before the others" do
    plain = Chadcn::Chart::Bar.new(data_key: :a, label: true)
    custom = Chadcn::Chart::Bar.new(data_key: :a, label: { position: :top })
    explicit = Chadcn::Chart::LabelList.new
    custom.declare(explicit)

    assert_equal 1, plain.label_lists.size
    assert_equal :middle, plain.label_lists.first.options[:position]
    assert_equal(%i[top middle], custom.label_lists.map { |list| list.options[:position] })
    assert_empty Chadcn::Chart::Bar.new(data_key: :a).label_lists
  end

  test "a cell goes only in a bar, and nothing else goes in a series" do
    assert_raises(ArgumentError) { Chadcn::Chart::Line.new(data_key: :a).declare(Chadcn::Chart::Cell.new) }
    assert_raises(ArgumentError) { Chadcn::Chart::Bar.new(data_key: :a).declare(Chadcn::Chart::Bar.new(data_key: :b)) }
  end

  test "a series written outside any chart raises" do
    error = assert_raises(ArgumentError) { Class.new(Phlex::HTML) { def view_template = render(Chadcn::Chart::Bar.new(data_key: :a)) }.new.call }

    assert_match(/inside a chart/, error.message)
  end
end

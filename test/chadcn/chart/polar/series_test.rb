# frozen_string_literal: true

require_relative "polar_helper"

class Chadcn::Chart::Polar::SeriesTest < Chadcn::TestCase
  include PolarHelper

  test "a series knows its kind and keeps its options frozen" do
    series = [ Chadcn::Chart::Pie.new, Chadcn::Chart::Radar.new(data_key: :a), Chadcn::Chart::RadialBar.new(data_key: :a) ]

    assert_equal(%i[pie radar radial_bar], series.map(&:kind))
    assert(series.all? { |one| one.options.frozen? })
  end

  test "label lists, cells and labels written in the block belong to the series, in order" do
    pie = Chadcn::Chart::Pie.new
    pie.declare(list = Chadcn::Chart::LabelList.new)
    pie.declare(cell = Chadcn::Chart::Cell.new(fill: "blue"))
    pie.declare(label = Chadcn::Chart::Label.new(value: "Total"))

    assert_equal [ list ], pie.label_lists
    assert_equal [ cell ], pie.cells
    assert_equal [ label ], pie.labels
  end

  test "label: on a radial bar or radar is an implicit label list, written before the others" do
    plain = Chadcn::Chart::RadialBar.new(data_key: :a, label: true)
    custom = Chadcn::Chart::Radar.new(data_key: :a, label: { position: :top })
    custom.declare(Chadcn::Chart::LabelList.new)

    assert_equal([ :middle ], plain.label_lists.map { |list| list.options[:position] })
    assert_equal(%i[top middle], custom.label_lists.map { |list| list.options[:position] })
    assert_empty Chadcn::Chart::Radar.new(data_key: :a).label_lists
  end

  test "a pie draws its own label unless the label asks for a position" do
    around = Chadcn::Chart::Pie.new(label: true)
    positioned = Chadcn::Chart::Pie.new(label: { position: :outside })

    assert_predicate around, :own_labels?
    assert_empty around.label_lists
    refute_predicate positioned, :own_labels?
    assert_equal([ :outside ], positioned.label_lists.map { |list| list.options[:position] })
    refute_predicate Chadcn::Chart::Pie.new, :own_labels?
  end

  test "a cell goes in a pie or a radial bar, a label in a pie, and nothing else goes in a series" do
    assert_raises(ArgumentError) { Chadcn::Chart::Radar.new(data_key: :a).declare(Chadcn::Chart::Cell.new) }
    assert_raises(ArgumentError) { Chadcn::Chart::RadialBar.new(data_key: :a).declare(Chadcn::Chart::Label.new) }
    assert_raises(ArgumentError) { Chadcn::Chart::Pie.new.declare(Chadcn::Chart::Pie.new) }
    Chadcn::Chart::RadialBar.new(data_key: :a).declare(Chadcn::Chart::Cell.new)
  end

  test "a series written outside any chart raises" do
    error = assert_raises(ArgumentError) { Class.new(Phlex::HTML) { def view_template = render(Chadcn::Chart::Pie.new) }.new.call }

    assert_match(/inside a chart/, error.message)
  end
end

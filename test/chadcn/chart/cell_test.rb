# frozen_string_literal: true

require_relative "cartesian/chart_helper"

class Chadcn::Chart::CellTest < Chadcn::TestCase
  test "the shape takes what was given, nothing else" do
    cell = Chadcn::Chart::Cell.new(fill: "red", stroke_width: 2, class: "c", "data-x": "1")

    assert_equal({ fill: "red", stroke_width: 2, class: "c", "data-x": "1" }, cell.shape_attributes)
    assert_empty Chadcn::Chart::Cell.new.shape_attributes
    assert_predicate cell.shape_attributes, :frozen?
  end

  test "outside a bar it raises" do
    assert_raises(ArgumentError) { Class.new(Phlex::HTML) { def view_template = render(Chadcn::Chart::Cell.new) }.new.call }
  end
end

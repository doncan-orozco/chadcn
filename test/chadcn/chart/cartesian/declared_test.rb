# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Cartesian::DeclaredTest < Chadcn::TestCase
  def declared = Chadcn::Chart::Cartesian::Declared.new

  test "keeps what was declared in order, split by kind" do
    list = declared
    parts = [ Chadcn::Chart::CartesianGrid.new, Chadcn::Chart::XAxis.new(x_axis_id: "a"), Chadcn::Chart::Bar.new(data_key: :a),
              Chadcn::Chart::Line.new(data_key: :b), Chadcn::Chart::ReferenceLine.new(y: 1), Chadcn::Chart::YAxis.new, Chadcn::Chart::Label.new(value: "x") ]
    parts.each { |part| list.declare(part) }

    assert_equal parts, list.items
    assert_equal %i[x y], list.axes.map(&:kind)
    assert_equal [ parts[2], parts[3] ], list.series
    assert_equal [ parts[4] ], list.references
    assert_equal [ parts[0] ], list.of(Chadcn::Chart::CartesianGrid)
  end

  test "tooltip and legend are kept for the overlays" do
    list = declared
    tooltip = Chadcn::Chart::Tooltip.new
    legend = Chadcn::Chart::Legend.new
    list.declare(tooltip)
    list.declare(legend)

    assert_same tooltip, list.tooltip
    assert_same legend, list.legend
  end

  test "axis ids lists every id something refers to" do
    list = declared
    list.declare(Chadcn::Chart::Bar.new(data_key: :a, y_axis_id: "left"))
    list.declare(Chadcn::Chart::Line.new(data_key: :b))
    list.declare(Chadcn::Chart::CartesianGrid.new(y_axis_id: "right"))

    assert_equal [ "left", 0, "right" ], list.axis_ids(:y)
    assert_equal [ 0 ], list.axis_ids(:x)
  end

  test "a part that does not go directly in a chart raises" do
    assert_raises(ArgumentError) { declared.declare(Chadcn::Chart::Cell.new) }
    assert_raises(ArgumentError) { declared.declare(Chadcn::Chart::LabelList.new) }
  end

  test "a second tooltip or legend is refused" do
    list = declared
    list.declare(Chadcn::Chart::Tooltip.new)
    list.declare(Chadcn::Chart::Legend.new)

    tooltip = assert_raises(ArgumentError) { list.declare(Chadcn::Chart::Tooltip.new) }
    legend = assert_raises(ArgumentError) { list.declare(Chadcn::Chart::Legend.new) }

    assert_equal "a chart takes one tooltip (got a second Chadcn::Chart::Tooltip)", tooltip.message
    assert_equal "a chart takes one legend (got a second Chadcn::Chart::Legend)", legend.message
    assert_equal 2, list.items.size
  end
end

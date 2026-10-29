# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Polar::AxisSettingsTest < Chadcn::TestCase
  Settings = Chadcn::Chart::Polar::AxisSettings

  test "an axis nobody declared has recharts' implicit settings" do
    angle = Settings.implicit(:angle)
    radius = Settings.implicit(:radius, "r")

    assert_equal [ :auto, false, nil, :outer ], [ angle.type, angle.allow_decimals, angle.tick_count, angle.orientation ]
    assert_equal [ 5, :right, "r" ], [ radius.tick_count, radius.orientation, radius.id ]
    assert_predicate angle, :angle?
    refute_predicate radius, :angle?
  end

  test "a built axis keeps its values and its type, orientation and shape are checked, names are strings or symbols" do
    built = Settings.build(:angle, type: "number", orientation: "inner", axis_line_type: "circle", domain: [ 0, :auto ], tick_formatter: { slice: [ 0, 1 ] },
                                   axis_id: "a", data_key: :x, reversed: false, allow_decimals: false, tick_count: nil, tick: true, tick_line: true,
                                   axis_line: true, tick_size: 8, angle: 0, stroke: nil, attrs: {})

    assert_equal [ :number, :inner, :circle, "a" ], [ built.type, built.orientation, built.axis_line_type, built.id ]
    assert_equal [ 0, "auto" ], built.domain
    assert_equal "J", built.tick_formatter.call("January")
    assert_raises(ArgumentError) { Settings.build(:angle, **base(type: :weird)) }
    assert_raises(ArgumentError) { Settings.build(:angle, **base(orientation: :left)) }
    assert_raises(ArgumentError) { Settings.build(:radius, **base(orientation: :inner)) }
    assert_raises(ArgumentError) { Settings.build(:angle, **base(domain: [ 1 ])) }
  end

  test "the domain bounds are recharts' keywords" do
    built = Settings.build(:radius, **base(domain: [ :data_min, "dataMax" ], orientation: :left))

    assert_equal %w[dataMin dataMax], built.domain
  end

  test "the cartesian settings read the angle as an x axis without nice ticks, the radius as a y axis with them" do
    angle = Settings.implicit(:angle).to_cartesian(:category)
    radius = Settings.implicit(:radius).to_cartesian(:number)

    assert_equal [ :x, :none, false, 10 ], [ angle.kind, angle.nice_ticks, angle.allow_duplicated_category, angle.tick_count ]
    assert_equal [ :y, :auto, true, 5 ], [ radius.kind, radius.nice_ticks, radius.allow_duplicated_category, radius.tick_count ]
  end

  def base(**changes)
    { type: :auto, orientation: :outer, axis_line_type: :polygon, domain: nil, tick_formatter: nil, axis_id: 0, data_key: nil, reversed: false,
      allow_decimals: false, tick_count: nil, tick: true, tick_line: true, axis_line: true, tick_size: 8, angle: 0, stroke: nil, attrs: {} }.merge(changes)
  end
end

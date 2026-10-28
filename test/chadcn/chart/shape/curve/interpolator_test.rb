# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Chart::Shape::Curve::InterpolatorTest < Chadcn::TestCase
  Interpolator = Chadcn::Chart::Shape::Curve::Interpolator
  Path = Chadcn::Chart::Shape::Path

  # A drawing context that remembers what the curve closed.
  class Spy
    attr_reader :calls

    def initialize = @calls = []

    def close = @calls << :close
  end

  # Records the Floats `point` hands to add_point.
  class Recorder < Interpolator
    attr_reader :seen

    private

    def add_point(x_coord, y_coord)
      (@seen ||= []) << [ x_coord, y_coord ]
      shift_window(x_coord, y_coord)
      self.point_count = point_count + 1
    end
  end

  test "point coerces to Float once and hands the Floats to add_point" do
    curve = Recorder.new(Path.new)
    curve.point(1, 2r)

    assert_equal [ [ 1.0, 2.0 ] ], curve.seen
    assert_instance_of Float, curve.seen.first.first
    assert_instance_of Float, curve.seen.first.last
  end

  test "a curve that does not implement add_point raises NotImplementedError" do
    assert_raises(NotImplementedError) { Interpolator.new(Path.new).point(1, 2) }
  end

  test "the default line_end closes a lone point and leaves longer lines open" do
    lone = Spy.new
    curve = Recorder.new(lone)
    curve.line_start
    curve.point(3, 4)
    curve.line_end

    assert_equal [ :close ], lone.calls

    longer = Spy.new
    curve = Recorder.new(longer)
    curve.line_start
    curve.point(3, 4)
    curve.point(5, 6)
    curve.line_end

    assert_empty longer.calls
  end
end

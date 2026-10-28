# frozen_string_literal: true

# rubocop:disable Naming/MethodParameterName -- x and y are the coordinate vocabulary of d3 and SVG

# d3-shape `curveStep` (t = 0.5), `curveStepBefore` (t = 0) and `curveStepAfter` (t = 1): horizontal and vertical segments.
#
# @api private
class Chadcn::Chart::Shape::Curve::Step < Chadcn::Chart::Shape::Curve::Interpolator
  # @api private
  # @param context [Chadcn::Chart::Shape::Path]
  # @param position [Numeric] where the step happens between two points: 0 before, 0.5 in the middle, 1 after
  def initialize(context, position)
    super(context)
    @t = position.to_f
  end

  # @api private
  # @return [void]
  def line_end
    draw_line_to(x1, y1) if @t.positive? && @t < 1 && point_count == 2
    close_path_if(point_count == 1)
    return unless inside_area?

    @t = 1 - @t
    toggle_line
  end

  private

  def add_point(x, y)
    if point_count.zero?
      self.point_count = 1
      start_subpath(x, y)
    else
      self.point_count = 2
      step_to(x, y)
    end
    shift_window(x, y)
  end

  def step_to(x, y)
    if @t <= 0
      draw_line_to(x1, y)
      draw_line_to(x, y)
    else
      middle = (x1 * (1 - @t)) + (x * @t)
      draw_line_to(middle, y1)
      draw_line_to(middle, y)
    end
  end
end

# rubocop:enable Naming/MethodParameterName

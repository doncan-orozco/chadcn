# frozen_string_literal: true

# What a polar chart's block declared, in the order it was written. The chart is the scope its direct children register with
# ({Chadcn::Chart::Cartesian::Scope}); the layout reads the lists, the renderer draws `items` in order.
#
# @api private
class Chadcn::Chart::Polar::Declared
  # @api private
  # @return [Array<#settings, #options>] every declaration, in order of declaration
  attr_reader :items
  # @api private
  # @return [Chadcn::Chart::Tooltip, nil]
  attr_reader :tooltip
  # @api private
  # @return [Chadcn::Chart::Legend, nil]
  attr_reader :legend
  # @api private
  # @return [Array<Chadcn::Chart::Polar::AxisSettings>] the declared angle axes, in order
  attr_reader :angle_axes
  # @api private
  # @return [Array<Chadcn::Chart::Polar::AxisSettings>] the declared radius axes, in order
  attr_reader :radius_axes
  # @api private
  # @return [Array<#options>] the pies, radars and radial bars, in order
  attr_reader :series

  # @param chart [Class] the chart class: its `CHART_TYPE` is the one kind of series it holds (`:pie` in a pie chart) and its `AXES` tells
  #   whether it holds polar axes (a pie chart does not)
  def initialize(chart:)
    @chart = chart
    @kind = chart::CHART_TYPE
    @axes = chart::AXES
    @items = []
    @angle_axes = []
    @radius_axes = []
    @series = []
    @tooltip = nil
    @legend = nil
  end

  # Registers a declaration.
  #
  # @api private
  # @param declaration [Object] a chart part
  # @return [void]
  # @raise [ArgumentError] on a part the chart cannot hold or a second tooltip or legend
  def declare(declaration)
    case declaration
    when Chadcn::Chart::Tooltip then @tooltip = single(@tooltip, declaration, "tooltip")
    when Chadcn::Chart::Legend then @legend = single(@legend, declaration, "legend")
    when Chadcn::Chart::PolarAngleAxis then axis(@angle_axes, declaration)
    when Chadcn::Chart::PolarRadiusAxis then axis(@radius_axes, declaration)
    when Chadcn::Chart::Polar::Series then @series << accepted_series(declaration)
    when Chadcn::Chart::PolarGrid, Chadcn::Chart::Label then nil
    else raise ArgumentError, unsupported(declaration)
    end
    @items << declaration
  end

  # @api private
  # @param kind [Class] a declaration class
  # @return [Array<Object>] the declarations of that class, in order
  def of(kind) = @items.grep(kind)

  private

  def accepted_series(declaration)
    return declaration if declaration.kind == @kind

    raise ArgumentError, "#{declaration.class.name} does not go in a #{@chart.name} (it holds a Chart::#{@kind.to_s.split('_').map(&:capitalize).join})"
  end

  def axis(list, declaration)
    raise ArgumentError, "#{declaration.class.name} does not go in a #{@chart.name} (it has no polar axes)" unless @axes

    list << declaration.settings
  end

  def single(current, declaration, name)
    raise ArgumentError, "a chart takes one #{name} (got a second #{declaration.class.name})" if current

    declaration
  end

  def unsupported(declaration)
    "#{declaration.class.name} does not go directly in a #{@chart.name} (a LabelList or a Cell goes in a series)"
  end
end

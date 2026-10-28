# frozen_string_literal: true

# What a chart's block declared, in the order it was written. The chart is the scope its direct children register with
# ({Chadcn::Chart::Cartesian::Scope}); the layout reads the lists, the renderer draws `items` in order.
#
# @api private
class Chadcn::Chart::Cartesian::Declared
  # @api private
  # @return [Array<#render_into>] every declaration, in order of declaration
  attr_reader :items
  # @api private
  # @return [Chadcn::Chart::Tooltip, nil]
  attr_reader :tooltip
  # @api private
  # @return [Chadcn::Chart::Legend, nil]
  attr_reader :legend

  def initialize
    @items = []
    @axes = []
    @series = []
    @references = []
    @tooltip = nil
    @legend = nil
  end

  # Registers a declaration.
  #
  # @api private
  # @param declaration [Object] a chart part
  # @return [void]
  # @raise [ArgumentError] on a part a chart cannot hold (a `Cell` outside a bar) or a second tooltip or legend
  def declare(declaration)
    case declaration
    when Chadcn::Chart::XAxis, Chadcn::Chart::YAxis then @axes << declaration.settings
    when Chadcn::Chart::Tooltip then @tooltip = single(@tooltip, declaration, "tooltip")
    when Chadcn::Chart::Legend then @legend = single(@legend, declaration, "legend")
    when Chadcn::Chart::Cartesian::Series then @series << declaration
    when Chadcn::Chart::ReferenceLine then @references << declaration
    when Chadcn::Chart::CartesianGrid, Chadcn::Chart::Label then nil
    else raise ArgumentError, "#{declaration.class.name} does not go directly in a chart (a LabelList or a Cell goes in a Bar, a Line or an Area)"
    end
    @items << declaration
  end

  # @api private
  # @return [Array<Chadcn::Chart::Cartesian::AxisSettings>] the declared axes, in order
  attr_reader :axes
  # @api private
  # @return [Array<#options>] the bars, lines and areas, in order
  attr_reader :series
  # @api private
  # @return [Array<Chadcn::Chart::ReferenceLine>]
  attr_reader :references

  # The ids of the axes of a kind that something refers to (a series, a grid, a reference line).
  #
  # @api private
  # @param kind [Symbol] :x or :y
  # @return [Array<Object>]
  def axis_ids(kind)
    key = kind == :x ? :x_axis_id : :y_axis_id
    (@series + @references + @items.grep(Chadcn::Chart::CartesianGrid)).map { |item| item.options[key] }.uniq
  end

  # @api private
  # @param kind [Class] a declaration class
  # @return [Array<Object>] the declarations of that class, in order
  def of(kind) = @items.grep(kind)

  private

  def single(current, declaration, name)
    raise ArgumentError, "a chart takes one #{name} (got a second #{declaration.class.name})" if current

    declaration
  end
end

# frozen_string_literal: true

# What a chart's block is made of: `Chart::Bar`, `Chart::XAxis`, `Chart::CartesianGrid` and the others. A declaration renders nothing
# where it is written; it registers itself with the chart (or the series) it is written in, and the chart lays everything out in one
# pass once its block has run, then draws it (dev/port/specs/chart.md, "The recharts layer"). Order of declaration is the order of
# drawing inside a layer, as in React.
#
# Every subclass gets a helper on {Chadcn::Chart::Declarations}, the module every chart class includes, so a chart's block reads like the
# JSX (`chart.bar(data_key: :desktop)` is `render Chadcn::Chart::Bar.new(data_key: :desktop)`). The helper is generated here, from the
# class name, and captures the class, so it does not depend on the order the constants are loaded in.
class Chadcn::Chart::Declaration < Chadcn::Base
  # @api private
  def self.inherited(subclass)
    super
    return if subclass.name.nil?

    helper = Chadcn::Chart::Declarations.helper_name(subclass.name)
    raise ArgumentError, "helper ##{helper} (from #{subclass}) would override a Ruby/Phlex API method" if Chadcn::Base.reserved_helper_names.include?(helper)

    Chadcn::Chart::Declarations.define_method(helper) { |**attrs, &block| render subclass.new(**attrs), &block }
  end

  # Registers the declaration with the chart it is written in.
  #
  # @return [void]
  # @raise [ArgumentError] outside a chart, or inside a series that cannot hold it
  def view_template
    scope = Chadcn::Chart::Cartesian::Scope.current(context)
    raise ArgumentError, "#{self.class.name} has to be written inside a chart (Chart::BarChart, Chart::LineChart or Chart::AreaChart)" unless scope

    scope.declare(self)
  end
end

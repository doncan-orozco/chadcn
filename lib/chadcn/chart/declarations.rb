# frozen_string_literal: true

# The helpers a chart class offers for its declarations (`chart.bar`, `chart.x_axis`, ...), one per {Chadcn::Chart::Declaration} subclass.
# They are defined here by `Declaration.inherited`, never written by hand, and each equals `render Chadcn::Chart::<Class>.new(**attrs, &block)`.
# Every chart class (and every series, for `label_list` and `cell`) includes this module, so a helper defined after the classes exist is
# visible to all of them.
#
# {Chadcn::Chart::Tooltip} and {Chadcn::Chart::Legend} are declarations too, but their classes predate this module and do not inherit
# from {Chadcn::Chart::Declaration}: their helpers register them with the chart by hand.
#
# @api private
module Chadcn::Chart::Declarations
  class << self
    # `XAxis` => `:x_axis`, `LabelList` => `:label_list`.
    #
    # @api private
    # @param class_name [String] the full class name
    # @return [Symbol]
    def helper_name(class_name)
      class_name.split("::").last.gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2').gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.to_sym
    end
  end

  # @param attrs [Hash] the keywords of {Chadcn::Chart::Tooltip}
  # @return [void]
  def tooltip(**attrs, &) = declare_element(Chadcn::Chart::Tooltip.new(**attrs), &)

  # @param attrs [Hash] the keywords of {Chadcn::Chart::Legend}
  # @return [void]
  def legend(**attrs, &) = declare_element(Chadcn::Chart::Legend.new(**attrs), &)

  private

  def declare_element(element, &)
    scope = Chadcn::Chart::Cartesian::Scope.current(context)
    raise ArgumentError, "#{element.class.name} has to be written inside a chart" unless scope

    scope.declare(element)
    render(element, &)
  end
end

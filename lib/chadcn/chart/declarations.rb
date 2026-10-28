# frozen_string_literal: true

# The helpers a chart class offers for its declarations (`chart.bar`, `chart.x_axis`, ...), one per {Chadcn::Chart::Declaration} subclass.
# They are defined here by `Declaration.inherited`, never written by hand, and each equals `render Chadcn::Chart::<Class>.new(**attrs, &block)`.
# Every chart class (and every series, for `label_list` and `cell`) includes this module, so a helper defined after the classes exist is
# visible to all of them.
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
end

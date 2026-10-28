# frozen_string_literal: true

# Who the declarations being rendered register with: the chart, or a series while its block runs (a `LabelList` and a `Cell` belong to
# the series they are written in). Published in the Phlex render context, the way {Chadcn::Chart::Container} publishes itself.
#
# @api private
module Chadcn::Chart::Cartesian::Scope
  KEY = :chadcn_chart_scope

  private_constant :KEY

  class << self
    # @api private
    # @param context [Hash] the Phlex render context
    # @return [#declare, nil]
    def current(context) = context[KEY]

    # Runs the block with `scope` as the current one, then puts the previous one back.
    #
    # @api private
    # @param context [Hash] the Phlex render context
    # @param scope [#declare]
    # @return [Object] what the block returns
    def with(context, scope)
      previous = context[KEY]
      context[KEY] = scope
      yield
    ensure
      previous ? context[KEY] = previous : context.delete(KEY)
    end
  end
end

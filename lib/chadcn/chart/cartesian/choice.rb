# frozen_string_literal: true

# The one validator of an option that takes a fixed set of values (`type: :monotone`, `layout: :vertical`): the value as a Symbol, or an
# `ArgumentError` naming the option and the values. Included by the chart root and the series, extended by the axis settings.
#
# @api private
module Chadcn::Chart::Cartesian::Choice
  private

  # @param name [Symbol] the keyword, for the message
  # @param value [Object] what the caller passed
  # @param allowed [Array<Symbol>]
  # @return [Symbol]
  # @raise [ArgumentError] unless `value` is one of `allowed`
  def choice(name, value, allowed)
    return value.to_sym if value.respond_to?(:to_sym) && allowed.include?(value.to_sym)

    raise ArgumentError, "#{name}: must be one of #{allowed.map(&:inspect).join(', ')} (got #{value.inspect})"
  end
end

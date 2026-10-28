# frozen_string_literal: true

# Which items share a stack: recharts groups bars and areas by `stackId` before stacking each group.
#
# @api private
module Chadcn::Chart::Shape::Stack::Groups
  class << self
    # Groups items by stack id, in order of first appearance; items without an id are alone in their group (they are not stacked).
    # Ids compare as strings, so `1` and `"1"` are the same stack.
    #
    # @api private
    # @param items [Array<Object>]
    # @yieldparam item [Object]
    # @yieldreturn [Object, nil] the stack id of the item
    # @return [Array<Array<Object>>]
    def by_id(items)
      groups = {}
      items.each_with_index do |item, index|
        id = yield(item)
        (groups[id.nil? ? [ :alone, index ] : id.to_s] ||= []) << item
      end
      groups.values
    end
  end
end

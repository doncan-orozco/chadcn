# frozen_string_literal: true

# What `Chart::Bar`, `Chart::Line` and `Chart::Area` share: the frozen `options`, the registration with the chart and the scope for the
# parts written in their block (`label_list`, and `cell` for a bar), plus the `label:` shortcut of recharts (`label: true` or a Hash is
# an implicit `LabelList`).
#
# @api private
module Chadcn::Chart::Cartesian::Series
  include Chadcn::Chart::Declarations

  # @api private
  # @return [Hash{Symbol => Object}] the keywords with recharts' defaults applied, frozen
  attr_reader :options

  # Registers with the chart, then runs the block with the series as the scope of the parts written in it.
  #
  # @api private
  # @yieldparam series [Chadcn::Base] itself
  # @return [void]
  def view_template(&block)
    super()
    return unless block

    Chadcn::Chart::Cartesian::Scope.with(context, self) { yield self }
  end

  # @api private
  # @return [Symbol] :bar, :line or :area
  def kind = self.class::KIND

  # The `LabelList`s of the series, the one `label:` asks for first.
  #
  # @api private
  # @return [Array<Chadcn::Chart::LabelList>]
  def label_lists
    implicit_label_list + @label_lists
  end

  # @api private
  # @return [Array<Chadcn::Chart::Cell>] the cells, in order (a cell styles the shape at its index)
  def cells = @cells

  # Registers a part written in the series' block.
  #
  # @api private
  # @param part [Object]
  # @return [void]
  # @raise [ArgumentError] on a part the series cannot hold
  def declare(part)
    case part
    when Chadcn::Chart::LabelList then @label_lists << part
    when Chadcn::Chart::Cell
      raise ArgumentError, "#{part.class.name} goes in a Chart::Bar, not in a Chart::#{kind.to_s.capitalize}" unless kind == :bar

      @cells << part
    else raise ArgumentError, "#{part.class.name} does not go in a Chart::#{kind.to_s.capitalize}"
    end
  end

  private

  # The `label:` shortcut of recharts: `true`, or the keywords of a list.
  def implicit_label_list
    label = options[:label]
    return [] unless label

    [ label.is_a?(Hash) ? Chadcn::Chart::LabelList.new(**label) : Chadcn::Chart::LabelList.new ]
  end

  def initialize_series
    @label_lists = []
    @cells = []
  end

  def choice(name, value, allowed)
    return value.to_sym if value.respond_to?(:to_sym) && allowed.include?(value.to_sym)

    raise ArgumentError, "#{name}: must be one of #{allowed.map(&:inspect).join(', ')} (got #{value.inspect})"
  end
end

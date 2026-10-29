# frozen_string_literal: true

# What `Chart::Pie`, `Chart::Radar` and `Chart::RadialBar` share: the frozen `options`, the registration with the chart, and the scope for
# the parts written in their block (`label_list`, `cell` for a pie and a radial bar, `label` for a pie), plus the `label:` shortcut
# of recharts (`label: true` or a Hash is an implicit `LabelList`, polar/Radar.js:195, polar/RadialBar.js:128).
#
# @api private
module Chadcn::Chart::Polar::Series
  include Chadcn::Chart::Declarations
  include Chadcn::Chart::Cartesian::Choice

  # recharts' `LegendType`.
  LEGEND_TYPES = %i[line plainline square rect circle cross diamond star triangle wye none].freeze

  # Where each kind may hold a `Cell` (polar/Pie.js:576, polar/RadialBar.js:299) and a `Label` (a pie's children, polar/Pie.js:540).
  CELL_KINDS = %i[pie radial_bar].freeze
  LABEL_KINDS = %i[pie].freeze

  private_constant :CELL_KINDS, :LABEL_KINDS

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
  # @return [Symbol] :pie, :radar or :radial_bar
  def kind = self.class::KIND

  # The `LabelList`s of the series, the one `label:` asks for first.
  #
  # @api private
  # @return [Array<Chadcn::Chart::LabelList>]
  def label_lists = implicit_label_list + @label_lists

  # @api private
  # @return [Array<Chadcn::Chart::Cell>] the cells, in order (a cell styles the sector at its index)
  def cells = @cells

  # @api private
  # @return [Array<Chadcn::Chart::Label>] the labels written in the block (a pie's centered total)
  def labels = @labels

  # Registers a part written in the series' block.
  #
  # @api private
  # @param part [Object]
  # @return [void]
  # @raise [ArgumentError] on a part the series cannot hold
  def declare(part)
    case part
    when Chadcn::Chart::LabelList then @label_lists << part
    when Chadcn::Chart::Cell then hold(part, @cells, CELL_KINDS, "Chart::Pie or Chart::RadialBar")
    when Chadcn::Chart::Label then hold(part, @labels, LABEL_KINDS, "Chart::Pie")
    else raise ArgumentError, "#{part.class.name} does not go in a #{self.class.name}"
    end
  end

  private

  def hold(part, list, kinds, where)
    raise ArgumentError, "#{part.class.name} goes in a #{where}, not in a #{self.class.name}" unless kinds.include?(kind)

    list << part
  end

  # The `label:` shortcut of recharts: `true`, or the keywords of a list.
  def implicit_label_list
    label = options[:label]
    return [] unless label && label_list_shortcut?

    [ label.is_a?(Hash) ? Chadcn::Chart::LabelList.new(**label) : Chadcn::Chart::LabelList.new ]
  end

  # A pie draws its `label:` itself (lines and text around the pie, polar/Pie.js:218) unless the Hash asks for a `position:`, which makes it a
  # label list (polar/Pie.js:265).
  def label_list_shortcut? = kind != :pie || !own_labels?

  def initialize_series
    @label_lists = []
    @cells = []
    @labels = []
  end
end

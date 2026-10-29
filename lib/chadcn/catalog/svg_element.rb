# frozen_string_literal: true

# An SVG element of a scenario tree (`_defs`, `_linearGradient`, `_stop`): the counterpart of {Chadcn::Catalog::RawElement}, which
# writes HTML tags only. Attribute names are written by Phlex (`stop_color:` is `stop-color`).
#
# @api private
class Chadcn::Catalog::SvgElement < Phlex::SVG
  # The tags a scenario may write; the name comes from scenario JSON, so nothing else is sent to Phlex.
  #
  # @api private
  TAGS = %w[defs linearGradient radialGradient stop].freeze

  # @param name [String] the tag name, in the case SVG spells it (`linearGradient`)
  # @param attrs [Hash] the attributes
  # @raise [ArgumentError] when the name is not in {TAGS}
  def initialize(name, **attrs)
    raise ArgumentError, "unknown SVG element #{name.inspect}" unless TAGS.include?(name.to_s)

    @name = name.to_s
    @attrs = attrs
    super()
  end

  # @return [void]
  def view_template(&) = public_send(@name, **@attrs, &)
end

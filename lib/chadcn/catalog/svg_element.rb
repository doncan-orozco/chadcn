# frozen_string_literal: true

# An SVG element of a scenario tree (`_defs`, `_linearGradient`, `_stop`): the counterpart of {Chadcn::Catalog::RawElement}, which
# writes HTML tags only. Attribute names are written by Phlex (`stop_color:` is `stop-color`).
#
# @api private
class Chadcn::Catalog::SvgElement < Phlex::SVG
  # @param name [String] the tag name, in the case SVG spells it (`linearGradient`)
  # @param attributes [Hash] the attributes
  def initialize(name, **attributes)
    @name = name
    @attributes = attributes
    super()
  end

  # @return [void]
  def view_template(&) = public_send(@name, **@attributes, &)
end

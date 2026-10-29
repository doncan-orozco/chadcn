# frozen_string_literal: true

# The `style` of the two wrappers recharts renders in the chart (tooltip and legend): a Hash of React style properties (`zIndex: 3`,
# `backgroundColor: "red"`) or a String, written the way React DOM writes them. Used for the attribute the server renders and for the
# `wrapperStyle` value `chadcn--chart` applies last.
#
# @api private
module Chadcn::Chart::Cartesian::CssStyle
  Number = Chadcn::Chart::Shape::Number

  UNITLESS = %i[z-index opacity flex flex-grow flex-shrink order line-height font-weight].freeze

  private_constant :Number, :UNITLESS

  module_function

  # The style attribute: the base properties with the caller's Hash merged over them, or a String appended.
  #
  # @param base [Hash{Symbol => Object}] CSS names
  # @param extra [Hash, String, nil]
  # @return [String]
  def text(base, extra)
    base = base.merge(extra.to_h { |name, value| [ css_name(name), value ] }) if extra.is_a?(Hash)
    text = base.map { |name, value| "#{name}: #{css_value(name, value)};" }.join(" ")
    extra.is_a?(String) ? "#{text} #{extra}" : text
  end

  # A Hash of properties with CSS names and String values, for the browser to set one by one. A String is split into its declarations.
  #
  # @param extra [Hash, String, nil]
  # @return [Hash{String => String}]
  def declarations(extra)
    case extra
    when Hash then extra.to_h { |name, value| [ css_name(name).to_s, css_value(css_name(name), value).to_s ] }
    when String then extra.split(";").filter_map { |part| part.split(":", 2).map(&:strip) if part.include?(":") }.to_h
    else {}
    end
  end

  # A property name the CSS way: `zIndex` and `z_index` are `z-index`; a custom property (`--gap`) is kept as written.
  def css_name(name)
    text = name.to_s
    return text.to_sym if text.start_with?("--")

    kebab = text.gsub(/([a-z\d])([A-Z])/, '\1-\2').tr("_", "-").downcase
    # A vendor prefix in the React spelling (WebkitTransition) is a leading dash in CSS (-webkit-transition).
    kebab = "-#{kebab}" if text.match?(/\A(?:Webkit|Moz|Ms|O)[A-Z]/)
    kebab.to_sym
  end

  # A number is pixels, as React DOM writes it, except for the properties that take a plain number.
  def css_value(name, value)
    return value unless value.is_a?(Numeric)

    UNITLESS.include?(name) || value.zero? ? Number.format(value) : "#{Number.format(value)}px"
  end
end

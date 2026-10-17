# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# shadcn AspectRatio over Radix AspectRatio: a box that keeps a width/height +ratio+ and positions its content to fill it.
# Like Radix it renders a padding-bottom wrapper plus an absolutely positioned inner element; +class+ is applied verbatim (no Tailwind merge).
#
# @example
#   Phlex::Shadcn::AspectRatio.new(ratio: 16.0 / 9) { img(src: "/cover.jpg", class: "size-full object-cover") }
class Phlex::Shadcn::AspectRatio < Phlex::Shadcn::Base
  # Inline positioning styles of the inner element; part of the DOM contract, not of the Ruby API.
  #
  # @api private
  FORCED_STYLE = "position: absolute; top: 0px; right: 0px; bottom: 0px; left: 0px;"

  # @param ratio [Numeric] positive width / height of the box
  # @param as_child [Boolean, Symbol, Phlex::Shadcn::Base] render this element (a tag name or component instance) instead of the default one (Radix +asChild+)
  # @param style [String, Hash, nil] caller styles, applied before the positioning styles
  # @param attrs [Hash] attributes of the inner, absolutely positioned element (the wrapper only carries
  #   +data-radix-aspect-ratio-wrapper+); +class+ is applied verbatim (no Tailwind merge), +data+/+aria+ are deep-merged
  def initialize(ratio: 1, as_child: false, style: nil, **attrs)
    @ratio = ratio
    @as_child = as_child
    @style = style
    @attrs = attrs
    super()
  end

  # Renders the element with the block as its content.
  #
  # @return [void]
  def view_template(&block)
    div(style: "position: relative; width: 100%; padding-bottom: #{padding_bottom}%;", data: { radix_aspect_ratio_wrapper: "" }) do
      inner_attrs = { data: { slot: "aspect-ratio" } }.merge_deep(canonical_attrs(@attrs)).merge(style: inner_style)
      if @as_child
        render_as_child(@as_child, **inner_attrs, &block)
      else
        div(**inner_attrs, &block)
      end
    end
  end

  private

  def padding_bottom
    value = 100 / @ratio.to_f
    value == value.to_i ? value.to_i.to_s : value.to_s
  end

  def inner_style
    caller_style = style_string(@style).to_s
    caller_style.empty? ? FORCED_STYLE : "#{caller_style}; #{FORCED_STYLE}"
  end

  def style_string(style)
    return super unless style.is_a?(Hash)

    style.map { |key, value| "#{key.to_s.tr('_', '-').gsub(/([a-z\d])([A-Z])/, '\1-\2').downcase}: #{value}" }.join("; ")
  end
end

# frozen_string_literal: true

# shadcn/ui AspectRatio over Radix AspectRatio. Spec: docs/shadcn-port/specs/aspect-ratio.md
# Radix renders a padding-bottom wrapper plus an absolutely positioned inner element; class is passed verbatim (no cn).
class Phlex::Shadcn::AspectRatio < Phlex::Shadcn::Base
  FORCED_STYLE = "position: absolute; top: 0px; right: 0px; bottom: 0px; left: 0px;"

  def initialize(ratio: 1, as_child: false, style: nil, **attrs)
    @ratio = ratio
    @as_child = as_child
    @style = style
    @attrs = attrs
    super()
  end

  def view_template(&block)
    div(style: "position: relative; width: 100%; padding-bottom: #{padding_bottom}%;", data: { radix_aspect_ratio_wrapper: "" }) do
      inner_attrs = { data: { slot: "aspect-ratio" } }.deep_merge(canonical_attrs(@attrs)).merge(style: inner_style)
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

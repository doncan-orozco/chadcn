# frozen_string_literal: true

# Action and Cancel: Button as slot around Primitive.Close. The Slot joins classes as plain strings (button
# classes first, then the caller class, no tailwind-merge), so a caller rounded-full keeps both radius classes.
module Phlex::Shadcn::AlertDialog::ActionButton
  include Phlex::Shadcn::AlertDialog::Support

  def initialize(variant: nil, size: "default", as_child: false, **attrs)
    @variant = normalize_option(variant) || default_variant
    @size = normalize_option(size) || "default"
    @button_classes = Phlex::Shadcn::Button.variants(variant: @variant, size: @size)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    attrs = merge_attrs({
                          type: "button",
                          data: slot_data.merge(variant: @variant, size: @size, v2__dialog_part: "close",
                                                action: "click->v2--alert-dialog#close")
                        }, @attrs.except(:class))
    attrs[:class] = [ @button_classes, *Array(@attrs[:class]) ].compact_blank.join(" ")
    render_part(:button, @as_child, attrs, &)
  end
end

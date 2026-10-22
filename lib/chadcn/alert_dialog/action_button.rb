# frozen_string_literal: true

# Action and Cancel: Button as slot around Primitive.Close. The Slot joins classes as plain strings (button
# classes first, then the caller class, no tailwind-merge), so a caller rounded-full keeps both radius classes.
using Chadcn::Values::Refinements

# Shared by Action and Cancel.
# @api private
module Chadcn::AlertDialog::ActionButton
  include Chadcn::AlertDialog::Support

  # @param variant [String, Symbol, nil] Button variant (Action defaults to "default", Cancel to "outline")
  # @param size [String, Symbol] Button size (default "default")
  # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(variant: nil, size: "default", as_child: false, **attrs)
    @variant = normalize_option(variant) || default_variant
    @size = normalize_option(size) || "default"
    @button_classes = Chadcn::Button.variants(variant: @variant, size: @size)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the button content
  # @return [void]
  def view_template(&)
    attrs = merge_attrs({
                          type: "button",
                          data: slot_data.merge(variant: @variant, size: @size, chadcn__dialog_part: "close",
                                                action: "click->chadcn--alert-dialog#close")
                        }, @attrs.except(:class))
    attrs[:class] = [ @button_classes, *Array(@attrs[:class]) ].reject_blank.join(" ")
    render_part(:button, @as_child, attrs, &)
  end
end

# frozen_string_literal: true

# Context menu flavour of the dropdown menu part helpers (item markup, position options, as_child switch).
# The data-v2--dropdown-menu-* names are the shared menu module's contract (template, sub ids, radio value).
module Phlex::Shadcn::ContextMenu::Support
  include Phlex::Shadcn::DropdownMenu::Support

  # Radix re-namespaces the popper variables on every (Sub)Content (CM:148-157, CM:246-256).
  STYLE_VARS = {
    "--radix-context-menu-content-transform-origin" => "var(--radix-popper-transform-origin)",
    "--radix-context-menu-content-available-width" => "var(--radix-popper-available-width)",
    "--radix-context-menu-content-available-height" => "var(--radix-popper-available-height)",
    "--radix-context-menu-trigger-width" => "var(--radix-popper-anchor-width)",
    "--radix-context-menu-trigger-height" => "var(--radix-popper-anchor-height)"
  }.freeze

  private

  def root_context
    context[Phlex::Shadcn::ContextMenu::ROOT_KEY] or raise ArgumentError, "#{self.class.name} must be used within ContextMenu"
  end

  # Parts without oracle classes do not call cn in shadcn: the caller's class is emitted untouched (no tailwind-merge).
  def verbatim_class(attrs, caller_attrs)
    css = flatten_class_inputs([ caller_attrs[:class] ]).join(" ")
    css.empty? ? attrs.except(:class) : attrs.merge(class: css)
  end

  def menu_content_attrs(classes:, slot:, id:, labelledby:, dir:)
    attrs = merge_attrs({
                          role: "menu", id:, dir:, class: classes,
                          aria: { orientation: "vertical", labelledby: },
                          data: { slot:, state: "open", radix_menu_content: "", orientation: "vertical" }
                        }, @attrs.except(:style))
    style = [ "outline: none", style_string(@attrs[:style]), *STYLE_VARS.map { |name, value| "#{name}: #{value}" } ]
    attrs.merge(style: style.compact_blank.join("; "))
  end
end

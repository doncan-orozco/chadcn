# frozen_string_literal: true

# What the parts share: the render context, the Radix MenuItemImpl + RovingFocusGroup.Item markup (the controller keeps
# tabindex and data-highlighted in sync afterwards), the Content markup and the as_child switch.
using Phlex::Shadcn::Values::Refinements

module Phlex::Shadcn::DropdownMenu::Support
  # shadcn does not set these; Radix re-namespaces the popper variables on every (Sub)Content (DM:125-135).
  STYLE_VARS = {
    "--radix-dropdown-menu-content-transform-origin" => "var(--radix-popper-transform-origin)",
    "--radix-dropdown-menu-content-available-width" => "var(--radix-popper-available-width)",
    "--radix-dropdown-menu-content-available-height" => "var(--radix-popper-available-height)",
    "--radix-dropdown-menu-trigger-width" => "var(--radix-popper-anchor-width)",
    "--radix-dropdown-menu-trigger-height" => "var(--radix-popper-anchor-height)"
  }.freeze

  private

  def root_context
    context[Phlex::Shadcn::DropdownMenu::ROOT_KEY] or raise ArgumentError, "#{self.class.name} must be used within DropdownMenu"
  end

  def item_attrs(disabled:, text_value: nil)
    {
      tabindex: "-1",
      data: { orientation: "vertical", radix_collection_item: "", disabled: disabled ? "" : nil, text_value: },
      aria: { disabled: disabled ? "true" : nil }
    }
  end

  # inset={false} renders data-inset=false in React; an omitted prop renders nothing.
  def inset_value(inset) = inset&.to_s

  # Content and SubContent: PopperContent + MenuContentImpl markup as it is when open.
  def menu_content_attrs(classes:, slot:, id:, labelledby:, dir:)
    attrs = merge_attrs({
                          role: "menu", id:, dir:, class: classes,
                          aria: { orientation: "vertical", labelledby: },
                          data: { slot:, state: "open", radix_menu_content: "", orientation: "vertical" }
                        }, @attrs.except(:style))
    style = [ "outline: none", style_string(@attrs[:style]), *STYLE_VARS.map { |name, value| "#{name}: #{value}" } ]
    attrs.merge(style: style.reject_blank.join("; "))
  end

  def position_options(**options)
    {
      sideOffset: options[:side_offset], align: options[:align].to_s, alignOffset: options[:align_offset],
      avoidCollisions: options[:avoid_collisions], collisionPadding: options[:collision_padding],
      collisionBoundary: options[:collision_boundary], arrowPadding: options[:arrow_padding], sticky: options[:sticky].to_s,
      hideWhenDetached: options[:hide_when_detached], updatePositionStrategy: options[:update_position_strategy].to_s,
      loop: options[:loop]
    }
  end

  def render_part(tag_name, as_child, attrs, &)
    return render_as_child(as_child, **attrs, &) if as_child

    tag(tag_name, **attrs, &)
  end
end

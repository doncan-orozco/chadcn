# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# shadcn TabsContent: Radix Content over Presence. React mounts the children only while the panel is present: inactive
# bodies ship in an inert template that the controller takes over on connect (an inactive as_child panel is only that
# template, since React renders nothing for it).
#
# @example
#   tabs.content(value: "account", force_mount: false) { "Account settings" }
class Phlex::Shadcn::Tabs::Content < Phlex::Shadcn::Base
  include Phlex::Shadcn::Tabs::Support

  # Default Tailwind classes of the panel.
  #
  # @api private
  CLASSES = "flex-1 outline-none"

  # @param value [String, Symbol] the tab value this panel belongs to
  # @param force_mount [Boolean] keep the panel mounted while inactive
  # @param as_child [false, nil, Symbol, String, Phlex::Shadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
  #   the part's attributes are merged onto it. `true` is not supported.
  # @param attrs [Hash] HTML attributes merged onto the panel (`style:` is joined with the mount-animation guard)
  def initialize(value:, force_mount: false, as_child: false, **attrs)
    @value = value.to_s
    @force_mount = force_mount
    @as_child = as_child
    @style = attrs.delete(:style)
    @attrs = attrs
    super()
  end

  # @yield the content of the element
  # @return [void]
  def view_template(&block)
    root = root_context
    selected = root[:value] == @value
    return render_deferred(root, &block) if !selected && !@force_mount && @as_child

    attrs = content_attrs(root, selected)
    return render_as_child(@as_child, **attrs, &block) if @as_child

    present = selected || @force_mount
    div(**attrs) do
      if present
        block&.call
      else
        template(data: { shadcn__tabs_target: "deferred" }) { block&.call }
      end
    end
  end

  private

  # The element as it will look when it mounts after a value change (active, no mount animation guard).
  def render_deferred(root, &block)
    attrs = content_attrs(root, true).merge(style: join_style(@style))
    template(data: { shadcn__tabs_target: "deferred", shadcn__tabs_item_value: @value, shadcn__tabs_as_child: "true" }) do
      render_as_child(@as_child, **attrs.reject_blank, &block)
    end
  end

  def content_attrs(root, selected)
    present = selected || @force_mount
    merge_attrs({
                  role: "tabpanel",
                  id: "#{root[:base_id]}-content-#{@value}",
                  tabindex: 0,
                  hidden: !present,
                  # Radix keeps the mount animation off for the panel that is selected at first render (isMountAnimationPrevented).
                  style: join_style(@style, ("animation-duration: 0s" if selected)),
                  class: CLASSES,
                  aria: { labelledby: "#{root[:base_id]}-trigger-#{@value}" },
                  data: { state: selected ? "active" : "inactive", orientation: root[:orientation], slot: "tabs-content",
                          shadcn__tabs_target: "content", shadcn__tabs_item_value: @value, shadcn__tabs_force_mount: @force_mount.to_s, shadcn__tabs_as_child: (@as_child ? "true" : nil) }
                }, @attrs)
  end
end

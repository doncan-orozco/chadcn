# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# shadcn CollapsibleContent. Radix mounts the children only while open: closed bodies ship in an inert template that the
# controller takes over on connect. With as_child a closed content renders no element at all, only that template.
#
# @example
#   c.content(force_mount: true) { "Body" }
class Phlex::Shadcn::Collapsible::Content < Phlex::Shadcn::Base
  include Phlex::Shadcn::Collapsible::Support

  # Inline style that suspends the mount animation for content present at first paint.
  #
  # @api private
  MOUNT_PREVENTION = "transition-duration: 0s; animation-name: none"

  # @param force_mount [Boolean] keep the children mounted while closed
  # @param as_child [false, nil, Symbol, String, Phlex::Shadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
  #   the part's attributes are merged onto it. `true` is not supported.
  # @param style [String, Hash, nil] inline style of the content element
  # @param attrs [Hash] HTML attributes merged onto the content element
  def initialize(force_mount: false, as_child: false, style: nil, **attrs)
    @force_mount = force_mount
    @as_child = as_child
    @style = style
    @attrs = attrs
    super()
  end

  # @yield the content of the element
  # @return [void]
  def view_template(&block)
    root = root_context
    mounted = root[:open] || @force_mount
    if @as_child
      return render_as_child(@as_child, **content_attrs(root, mounted), &block) if mounted

      template(data: { shadcn__collapsible_target: "body", shadcn__collapsible_slot: "child" }) do
        render_as_child(@as_child, **content_attrs(root, true, open: true, prevent: false), &block)
      end
    else
      div(**content_attrs(root, mounted)) do
        mounted ? block&.call : template(data: { shadcn__collapsible_target: "body" }) { block&.call }
      end
    end
  end

  private

  def content_attrs(root, mounted, open: root[:open], prevent: mounted)
    merge_attrs({
                  id: root[:content_id],
                  hidden: !mounted,
                  style: style_for(prevent),
                  data: { state: open ? "open" : "closed", disabled: disabled_data(root),
                          slot: "collapsible-content", shadcn__collapsible_target: "content",
                          shadcn__collapsible_force_mount: @force_mount.to_s, shadcn__collapsible_as_child: @as_child.filled?.to_s }
                }, @attrs)
  end

  # The mount animation stays suspended for content that is present at first paint (Radix isMountAnimationPrevented).
  def style_for(prevent)
    [ (MOUNT_PREVENTION if prevent), style_string(@style) ].reject_blank.join("; ")
  end
end

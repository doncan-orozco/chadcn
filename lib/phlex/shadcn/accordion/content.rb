# frozen_string_literal: true

using Phlex::Shadcn::Values::Refinements

# shadcn AccordionContent: the region div has fixed classes, the caller class goes to the inner div. Radix mounts the
# children only while open: closed bodies ship in an inert template that the controller takes over on connect.
#
# @example
#   acc.content(class: "text-muted-foreground") { "Body" }
class Phlex::Shadcn::Accordion::Content < Phlex::Shadcn::Base
  include Phlex::Shadcn::Accordion::Support

  # Tailwind classes of the region div.
  #
  # @api private
  CLASSES = "overflow-hidden text-sm data-[state=closed]:animate-accordion-up data-[state=open]:animate-accordion-down"
  # Default Tailwind classes of the inner div (the caller `class:` is merged here).
  #
  # @api private
  INNER_CLASSES = "pt-0 pb-4"
  # Inline style variables that alias the Radix content size to the collapsible ones.
  #
  # @api private
  VARS = "--radix-accordion-content-height: var(--radix-collapsible-content-height); --radix-accordion-content-width: var(--radix-collapsible-content-width)"
  # Inline style that suspends the mount animation for content present at first paint.
  #
  # @api private
  MOUNT_PREVENTION = "transition-duration: 0s; animation-name: none"

  # @param force_mount [Boolean] keep the children mounted while closed
  # @param style [String, Hash, nil] inline style of the region element
  # @param attrs [Hash] HTML attributes for the region; its `class:` goes to the inner div
  def initialize(force_mount: false, style: nil, **attrs)
    @force_mount = force_mount
    @style = style
    @inner_class = attrs.delete(:class)
    @attrs = attrs
    super()
  end

  # @yield the content of the element
  # @return [void]
  def view_template(&block)
    item = item_context
    mounted = item[:open] || @force_mount
    div(**region_attrs(item, mounted)) do
      if mounted
        inner(&block)
      else
        template(data: { shadcn__accordion_target: "body" }) { inner(&block) }
      end
    end
  end

  private

  def inner(&block)
    div(class: cn(INNER_CLASSES, @inner_class)) { block&.call }
  end

  def region_attrs(item, mounted)
    merge_attrs({
                  id: item[:content_id],
                  role: "region",
                  hidden: !mounted,
                  class: CLASSES,
                  style: style_for(mounted),
                  aria: { labelledby: item[:trigger_id] },
                  data: { state: state_of(item), disabled: disabled_data(item), orientation: item[:root][:orientation],
                          slot: "accordion-content", shadcn__accordion_target: "content", shadcn__accordion_force_mount: @force_mount.to_s }
                }, @attrs)
  end

  # The mount animation stays suspended for content that is present at first paint (Radix isMountAnimationPrevented).
  def style_for(mounted)
    [ VARS, style_string(@style), (MOUNT_PREVENTION if mounted) ].reject_blank.join("; ")
  end
end

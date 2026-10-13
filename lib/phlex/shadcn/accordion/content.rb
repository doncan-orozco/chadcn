# frozen_string_literal: true

# shadcn AccordionContent: the region div has fixed classes, the caller class goes to the inner div. Radix mounts the
# children only while open: closed bodies ship in an inert template that the controller takes over on connect.
class Phlex::Shadcn::Accordion::Content < Phlex::Shadcn::Base
  include Phlex::Shadcn::Accordion::Support

  CLASSES = "overflow-hidden text-sm data-[state=closed]:animate-accordion-up data-[state=open]:animate-accordion-down"
  INNER_CLASSES = "pt-0 pb-4"
  VARS = "--radix-accordion-content-height: var(--radix-collapsible-content-height); --radix-accordion-content-width: var(--radix-collapsible-content-width)"
  MOUNT_PREVENTION = "transition-duration: 0s; animation-name: none"

  def initialize(force_mount: false, style: nil, **attrs)
    @force_mount = force_mount
    @style = style
    @inner_class = attrs.delete(:class)
    @attrs = attrs
    super()
  end

  def view_template(&block)
    item = item_context
    mounted = item[:open] || @force_mount
    div(**region_attrs(item, mounted)) do
      if mounted
        inner(&block)
      else
        template(data: { v2__accordion_target: "body" }) { inner(&block) }
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
                          slot: "accordion-content", v2__accordion_target: "content", v2__accordion_force_mount: @force_mount.to_s }
                }, @attrs)
  end

  # The mount animation stays suspended for content that is present at first paint (Radix isMountAnimationPrevented).
  def style_for(mounted)
    [ VARS, style_string(@style), (MOUNT_PREVENTION if mounted) ].compact_blank.join("; ")
  end
end

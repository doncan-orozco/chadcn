# frozen_string_literal: true

using Chadcn::Values::Refinements

# vaul Content over Radix DialogContent, inside the Portal and Overlay the shadcn component renders. The first child is the
# shadcn drag bar (a plain div, not a vaul Handle). The direction comes from the Root.
class Chadcn::Drawer::Content < Chadcn::Base
  include Chadcn::Drawer::Support

  CLASSES = [
    "group/drawer-content fixed z-50 flex h-auto flex-col bg-background",
    "data-[vaul-drawer-direction=top]:inset-x-0 data-[vaul-drawer-direction=top]:top-0 data-[vaul-drawer-direction=top]:mb-24 data-[vaul-drawer-direction=top]:max-h-[80vh] data-[vaul-drawer-direction=top]:rounded-b-lg data-[vaul-drawer-direction=top]:border-b",
    "data-[vaul-drawer-direction=bottom]:inset-x-0 data-[vaul-drawer-direction=bottom]:bottom-0 data-[vaul-drawer-direction=bottom]:mt-24 data-[vaul-drawer-direction=bottom]:max-h-[80vh] data-[vaul-drawer-direction=bottom]:rounded-t-lg data-[vaul-drawer-direction=bottom]:border-t",
    "data-[vaul-drawer-direction=right]:inset-y-0 data-[vaul-drawer-direction=right]:right-0 data-[vaul-drawer-direction=right]:w-3/4 data-[vaul-drawer-direction=right]:border-l data-[vaul-drawer-direction=right]:sm:max-w-sm",
    "data-[vaul-drawer-direction=left]:inset-y-0 data-[vaul-drawer-direction=left]:left-0 data-[vaul-drawer-direction=left]:w-3/4 data-[vaul-drawer-direction=left]:border-r data-[vaul-drawer-direction=left]:sm:max-w-sm"
  ].freeze
  BAR_CLASSES = "mx-auto mt-4 hidden h-2 w-[100px] shrink-0 rounded-full bg-muted group-data-[vaul-drawer-direction=bottom]/drawer-content:block"

  # @param force_mount [Boolean] accepted for API parity; it has no effect (the inner Portal is not force-mounted, dialog:101)
  # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(force_mount: false, as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  # @raise [ArgumentError] when rendered outside Drawer
  def view_template
    root = root_context
    body = capture { yield if block_given? }
    portaled = context[Chadcn::Drawer::PORTAL_KEY]
    markup = proc do
      render Chadcn::Drawer::Overlay.new
      render_part(:div, @as_child, content_attrs(root)) do
        div(class: BAR_CLASSES)
        raw(safe(body))
      end
    end
    portaled ? instance_exec(&markup) : render(Chadcn::Drawer::Portal.new, &markup)
  end

  private

  def content_attrs(root)
    attrs = merge_attrs({
                          id: root[:content_id], role: "dialog", tabindex: "-1", class: cn(*CLASSES),
                          aria: { labelledby: (root[:title_id] if root[:title_present]) },
                          data: { slot: "drawer-content", state: "open", chadcn__dialog_part: "content", vaul_drawer: "",
                                  vaul_drawer_direction: root[:direction], vaul_delayed_snap_points: "false",
                                  vaul_snap_points: bool(root[:snap_points]), vaul_custom_container: bool(root[:container]),
                                  vaul_animate: bool(root[:animate]) }
                        }, @attrs)
    attrs.merge(aria: (attrs[:aria] || {}).merge(describedby: describedby(root, attrs.dig(:aria, :describedby))))
  end

  # concatAriaDescribedby (dialog:319-328): caller ids first, deduped.
  def describedby(root, caller_ids)
    ids = caller_ids.to_s.split
    ids << root[:description_id] if root[:description_present]
    ids.uniq.join(" ").unless_blank
  end
end

# frozen_string_literal: true

# vaul Overlay over Radix DialogOverlay. Renders nothing when the Root is `modal: false` (vaul:1392). The data-vaul-* flags are
# repainted by the controller on every state change.
class Chadcn::Drawer::Overlay < Chadcn::Base
  include Chadcn::Drawer::Support

  CLASSES = "fixed inset-0 z-50 bg-black/50 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:animate-in data-[state=open]:fade-in-0"

  # @param force_mount [Boolean] accepted for API parity; the Portal decides what stays mounted
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
  def view_template(&)
    root = root_context
    return unless root[:modal]

    attrs = merge_attrs({
                          class: CLASSES, style: "pointer-events: auto",
                          data: { slot: "drawer-overlay", state: "open", chadcn__dialog_part: "overlay", vaul_overlay: "",
                                  vaul_snap_points: bool(root[:snap_points]), vaul_snap_points_overlay: bool(root[:should_fade]),
                                  vaul_animate: bool(root[:animate]) }
                        }, @attrs)
    render_part(:div, @as_child, attrs, &)
  end
end

# frozen_string_literal: true

# shadcn DialogOverlay. Radix renders it only for modal dialogs (dialog:109).
#
# Backdrop of the dialog; rendered only when the root is modal.
class Chadcn::Dialog::Overlay < Chadcn::Base
  include Chadcn::Dialog::Support

  # @api private
  CLASSES = "fixed inset-0 z-50 bg-black/50 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:animate-in data-[state=open]:fade-in-0"

  # force_mount has no effect: the surrounding Portal owns the Presence gate (spec, forceMount).
  #
  # @param force_mount [Boolean] accepted for API parity only, it has no effect (the Portal owns the mount gate)
  # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(force_mount: false, as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  # @raise [ArgumentError] when rendered outside Dialog
  def view_template(&)
    return unless root_context[:modal]

    attrs = merge_attrs({
                          class: CLASSES, style: "pointer-events: auto", data: { slot: "dialog-overlay", state: "open",
                                                                                 chadcn__dialog_part: "overlay" }
                        }, @attrs)
    render_part(:div, @as_child, attrs, &)
  end
end

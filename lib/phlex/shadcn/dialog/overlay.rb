# frozen_string_literal: true

# shadcn DialogOverlay. Radix renders it only for modal dialogs (dialog:109).
class Phlex::Shadcn::Dialog::Overlay < Phlex::Shadcn::Base
  include Phlex::Shadcn::Dialog::Support

  CLASSES = "fixed inset-0 z-50 bg-black/50 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:animate-in data-[state=open]:fade-in-0"

  # force_mount has no effect: the surrounding Portal owns the Presence gate (spec, forceMount).
  def initialize(force_mount: false, as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    return unless root_context[:modal]

    attrs = merge_attrs({
                          class: CLASSES, style: "pointer-events: auto", data: { slot: "dialog-overlay", state: "open",
                                                                                 shadcn__dialog_part: "overlay" }
                        }, @attrs)
    render_part(:div, @as_child, attrs, &)
  end
end

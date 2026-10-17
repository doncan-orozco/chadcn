# frozen_string_literal: true

# shadcn AlertDialogContent = Portal + Overlay + Radix Content. The body is captured first because aria-labelledby /
# aria-describedby depend on whether a Title / Description was rendered inside (Radix learns it in an effect, dialog:261-262).
using Phlex::Shadcn::Values::Refinements

# Portal + Overlay + content panel (`role=alertdialog`) of the alert dialog; no close button.
#
# @example Explicit form
#   render Phlex::Shadcn::AlertDialog::Content.new { "Body" }
# @example Yielded-root helper form
#   alert_dialog.content { "Body" }
class Phlex::Shadcn::AlertDialog::Content < Phlex::Shadcn::Base
  include Phlex::Shadcn::AlertDialog::Support

  # @api private
  CLASSES = "group/alert-dialog-content fixed top-[50%] left-[50%] z-50 grid w-full max-w-[calc(100%-2rem)] translate-x-[-50%] translate-y-[-50%] gap-4 rounded-lg border bg-background p-6 shadow-lg duration-200 data-[size=sm]:max-w-xs data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95 data-[size=default]:sm:max-w-lg"
  # Accepted values of `size:`.
  # @return [Array<String>]
  SIZES = %w[default sm].freeze

  # force_mount has no effect: the Portal that shadcn wraps around the Content is not force-mounted (spec, forceMount).
  #
  # @param size [String, Symbol] "default" or "sm" (see SIZES); anything else raises ArgumentError
  # @param force_mount [Boolean] accepted for API parity only, it has no effect (the Portal owns the mount gate)
  # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  # @raise [ArgumentError] when `size:` is not a supported value
  def initialize(size: "default", force_mount: false, as_child: false, **attrs)
    @size = normalize_option(size) || "default"
    raise ArgumentError, "size must be one of #{SIZES.join(', ')}, got #{size.inspect}" unless SIZES.include?(@size)

    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the panel content
  # @return [void]
  # @raise [ArgumentError] when rendered outside AlertDialog
  def view_template
    root = root_context
    body = capture { yield if block_given? }
    portaled = context[Phlex::Shadcn::AlertDialog::PORTAL_KEY]
    markup = proc do
      render Phlex::Shadcn::AlertDialog::Overlay.new
      render_part(:div, @as_child, content_attrs(root, state_of(root))) { raw(safe(body)) }
    end
    portaled ? instance_exec(&markup) : render(Phlex::Shadcn::AlertDialog::Portal.new, &markup)
  end

  private

  def content_attrs(root, state)
    attrs = merge_attrs({
                          id: root[:content_id], role: "alertdialog", tabindex: "-1", class: CLASSES,
                          aria: { labelledby: (root[:title_id] if root[:title_present]) },
                          data: { slot: "alert-dialog-content", size: @size, state: state, shadcn__dialog_part: "content" }
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

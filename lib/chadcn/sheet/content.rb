# frozen_string_literal: true

# shadcn SheetContent = Portal + Overlay + Radix Content (+ the X close button). The body is captured first because
# aria-labelledby / aria-describedby depend on whether a Title / Description was rendered inside (Radix learns it in
# an effect, dialog:261-262).
using Chadcn::Values::Refinements

# Portal + Overlay + side-aware content panel of the sheet (+ the X close button).
#
# @example Explicit form
#   render Chadcn::Sheet::Content.new { "Body" }
# @example Yielded-root helper form
#   sheet.content { "Body" }
class Chadcn::Sheet::Content < Chadcn::Base
  include Chadcn::Sheet::Support

  # @api private
  CLASSES = "fixed z-50 flex flex-col gap-4 bg-background shadow-lg transition ease-in-out data-[state=closed]:animate-out data-[state=closed]:duration-300 data-[state=open]:animate-in data-[state=open]:duration-500"
  # @api private
  SIDES = {
    "right" => "inset-y-0 right-0 h-full w-3/4 border-l data-[state=closed]:slide-out-to-right data-[state=open]:slide-in-from-right sm:max-w-sm",
    "left" => "inset-y-0 left-0 h-full w-3/4 border-r data-[state=closed]:slide-out-to-left data-[state=open]:slide-in-from-left sm:max-w-sm",
    "top" => "inset-x-0 top-0 h-auto border-b data-[state=closed]:slide-out-to-top data-[state=open]:slide-in-from-top",
    "bottom" => "inset-x-0 bottom-0 h-auto border-t data-[state=closed]:slide-out-to-bottom data-[state=open]:slide-in-from-bottom"
  }.freeze
  # @api private
  CLOSE_CLASSES = "absolute top-4 right-4 rounded-xs opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:ring-2 focus:ring-ring focus:ring-offset-2 focus:outline-hidden disabled:pointer-events-none data-[state=open]:bg-secondary"

  # force_mount has no effect: the Portal that shadcn wraps around the Content is not force-mounted (spec, forceMount).
  #
  # @param side [String, Symbol] "right" (default), "left", "top" or "bottom"; anything else raises ArgumentError
  # @param show_close_button [Boolean] render the X close button as the last child (default true)
  # @param close_label [String] screen-reader text of the close button (default "Close")
  # @param force_mount [Boolean] accepted for API parity only, it has no effect (the Portal owns the mount gate)
  # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  # @raise [ArgumentError] when `side:` is not a supported value
  def initialize(side: "right", show_close_button: true, close_label: "Close", force_mount: false, as_child: false, **attrs)
    @side = (side || "right").to_s
    raise ArgumentError, "side must be one of #{SIDES.keys.join(', ')}, got #{side.inspect}" unless SIDES.key?(@side)

    @show_close_button = show_close_button
    @close_label = close_label
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the panel content
  # @return [void]
  # @raise [ArgumentError] when rendered outside Sheet
  def view_template
    root = root_context
    body = capture do
      yield if block_given?
      close_button if @show_close_button
    end
    portaled = context[Chadcn::Sheet::PORTAL_KEY]
    markup = proc do
      render Chadcn::Sheet::Overlay.new
      render_part(:div, @as_child, content_attrs(root)) { raw(safe(body)) }
    end
    portaled ? instance_exec(&markup) : render(Chadcn::Sheet::Portal.new, &markup)
  end

  private

  # The oracle renders Radix Close directly, so the X button has no data-slot (not sheet-close).
  def close_button
    button(type: "button", class: cn(CLOSE_CLASSES), data: { chadcn__dialog_part: "close", action: "click->chadcn--sheet#close" }) do
      render Chadcn::Icon.new("x", class: "size-4")
      span(class: "sr-only") { @close_label }
    end
  end

  def content_attrs(root)
    attrs = merge_attrs({
                          id: root[:content_id], role: "dialog", tabindex: "-1", class: cn(CLASSES, SIDES.fetch(@side)),
                          aria: { labelledby: (root[:title_id] if root[:title_present]) },
                          data: { slot: "sheet-content", state: "open", chadcn__dialog_part: "content" }
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

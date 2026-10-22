# frozen_string_literal: true

# shadcn DialogContent = Portal + Overlay + Radix Content (+ the X close button). The body is captured first because
# aria-labelledby / aria-describedby depend on whether a Title / Description was rendered inside (Radix learns it in
# an effect, dialog:261-262).
using Chadcn::Values::Refinements

# Portal + Overlay + content panel of the dialog (+ the X close button).
#
# @example Explicit form
#   render Chadcn::Dialog::Content.new { "Body" }
# @example Yielded-root helper form
#   dialog.content { "Body" }
class Chadcn::Dialog::Content < Chadcn::Base
  include Chadcn::Dialog::Support

  # @api private
  CLASSES = "fixed top-[50%] left-[50%] z-50 grid w-full max-w-[calc(100%-2rem)] translate-x-[-50%] translate-y-[-50%] gap-4 rounded-lg border bg-background p-6 shadow-lg duration-200 outline-none data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95 sm:max-w-lg"
  # @api private
  CLOSE_CLASSES = "absolute top-4 right-4 rounded-xs opacity-70 ring-offset-background transition-opacity hover:opacity-100 focus:ring-2 focus:ring-ring focus:ring-offset-2 focus:outline-hidden disabled:pointer-events-none data-[state=open]:bg-accent data-[state=open]:text-muted-foreground [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4"

  # force_mount has no effect: the Portal that shadcn wraps around the Content is not force-mounted (spec, forceMount).
  #
  # @param show_close_button [Boolean] render the X close button as the last child (default true)
  # @param close_label [String] screen-reader text of the close button (default "Close")
  # @param force_mount [Boolean] accepted for API parity only, it has no effect (the Portal owns the mount gate)
  # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(show_close_button: true, close_label: "Close", force_mount: false, as_child: false, **attrs)
    @show_close_button = show_close_button
    @close_label = close_label
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the panel content
  # @return [void]
  # @raise [ArgumentError] when rendered outside Dialog
  def view_template
    root = root_context
    body = capture do
      yield if block_given?
      close_button if @show_close_button
    end
    portaled = context[Chadcn::Dialog::PORTAL_KEY]
    markup = proc do
      render Chadcn::Dialog::Overlay.new
      render_part(:div, @as_child, content_attrs(root)) { raw(safe(body)) }
    end
    portaled ? instance_exec(&markup) : render(Chadcn::Dialog::Portal.new, &markup)
  end

  private

  def close_button
    render Chadcn::Dialog::Close.new(class: CLOSE_CLASSES) do
      render Chadcn::Icon.new("x")
      span(class: "sr-only") { @close_label }
    end
  end

  def content_attrs(root)
    attrs = merge_attrs({
                          id: root[:content_id], role: "dialog", tabindex: "-1", class: CLASSES,
                          aria: { labelledby: (root[:title_id] if root[:title_present]) },
                          data: { slot: "dialog-content", state: "open", shadcn__dialog_part: "content" }
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

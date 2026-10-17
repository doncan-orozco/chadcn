# frozen_string_literal: true

# shadcn DialogFooter. show_close_button appends a Close that wraps an outline Button.
#
# Layout wrapper for the actions (`div`).
class Phlex::Shadcn::Dialog::Footer < Phlex::Shadcn::Base
  # @param show_close_button [Boolean] append an outline Button that closes (default false)
  # @param close_label [String] screen-reader text of the close button (default "Close")
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(show_close_button: false, close_label: "Close", **attrs)
    @show_close_button = show_close_button
    @close_label = close_label
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  def view_template
    attrs = merge_attrs({ class: "flex flex-col-reverse gap-2 sm:flex-row sm:justify-end", data: { slot: "dialog-footer" } }, @attrs)
    div(**attrs) do
      yield if block_given?
      close_button if @show_close_button
    end
  end

  private

  # shadcn wraps the Button in a Close without data-slot, so the Button keeps its own: a Dialog::Close part would stamp dialog-close.
  def close_button
    render Phlex::Shadcn::Button.new(
      variant: "outline", type: "button", data: { shadcn__dialog_part: "close", action: "click->shadcn--dialog#close" }
    ) { @close_label }
  end
end

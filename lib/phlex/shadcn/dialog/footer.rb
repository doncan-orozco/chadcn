# frozen_string_literal: true

# shadcn DialogFooter. show_close_button appends a Close that wraps an outline Button.
class Phlex::Shadcn::Dialog::Footer < Phlex::Shadcn::Base
  def initialize(show_close_button: false, close_label: "Close", **attrs)
    @show_close_button = show_close_button
    @close_label = close_label
    @attrs = attrs
    super()
  end

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

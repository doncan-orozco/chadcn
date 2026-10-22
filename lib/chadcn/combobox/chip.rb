# frozen_string_literal: true

# shadcn ComboboxChip: one selected value in multiple mode (`div`) with its remove button.
#
# @example
#   render(Chadcn::Combobox::Chip.new { "Next.js" })
class Chadcn::Combobox::Chip < Chadcn::Base
  include Chadcn::Combobox::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "flex h-[calc(--spacing(5.5))] w-fit items-center justify-center gap-1 rounded-sm bg-muted px-1.5 text-xs font-medium whitespace-nowrap text-foreground has-disabled:pointer-events-none has-disabled:cursor-not-allowed has-disabled:opacity-50 has-data-[slot=combobox-chip-remove]:pr-0"

  # @param show_remove [Boolean] render the remove button
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(show_remove: true, **attrs)
    @show_remove = show_remove
    @attrs = attrs
    super()
  end

  # @yield the chip text
  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template(&block)
    model = root_model
    defaults = { tabindex: "-1", class: CLASSES, data: { slot: "combobox-chip", shadcn__combobox_part: "chip" } }
    defaults[:aria] = { disabled: (model.disabled? ? "true" : nil), readonly: (model.read_only? ? "true" : nil) }
    defaults[:data][:disabled] = "" if model.disabled?
    div(**merge_attrs(defaults, @attrs)) do
      block&.call
      remove_button(model) if @show_remove
    end
  end

  private

  def remove_button(model)
    render Chadcn::Button.new(
      variant: "ghost", size: "icon-xs", type: "button", tabindex: "-1", class: "-ml-1 opacity-50 hover:opacity-100",
      "data-slot": "combobox-chip-remove", "aria-disabled": model.disabled?.to_s,
      data: { disabled: (model.disabled? ? "" : nil), shadcn__combobox_part: "chip-remove" }
    ) { render Chadcn::Icon.new("x", class: "pointer-events-none") }
  end
end

# frozen_string_literal: true

# shadcn ComboboxChips: the container of the chips and the chips input in multiple mode (`div`; `role="toolbar"` while something is
# selected). Pressing it focuses the input and opens the popup. Its block usually holds a {Combobox::Value}.
#
# @example
#   render Phlex::Shadcn::Combobox::Chips.new do
#     render(Phlex::Shadcn::Combobox::Value.new) do |values|
#       values.each { |value| render(Phlex::Shadcn::Combobox::Chip.new { value }) }
#       render Phlex::Shadcn::Combobox::ChipsInput.new
#     end
#   end
class Phlex::Shadcn::Combobox::Chips < Phlex::Shadcn::Base
  include Phlex::Shadcn::Combobox::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "flex min-h-9 flex-wrap items-center gap-1.5 rounded-md border border-input bg-transparent bg-clip-padding px-2.5 py-1.5 text-sm shadow-xs transition-[color,box-shadow] focus-within:border-ring focus-within:ring-[3px] focus-within:ring-ring/50 has-aria-invalid:border-destructive has-aria-invalid:ring-[3px] has-aria-invalid:ring-destructive/20 has-data-[slot=combobox-chip]:px-1.5 dark:bg-input/30 dark:has-aria-invalid:border-destructive/50 dark:has-aria-invalid:ring-destructive/40"

  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the chips and the input
  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template(&)
    model = root_model
    model.input_outside = true
    defaults = { class: CLASSES, data: { slot: "combobox-chips", shadcn__combobox_part: "chips" } }
    defaults[:role] = "toolbar" if model.selection.any?
    div(**merge_attrs(defaults, @attrs), &)
  end
end

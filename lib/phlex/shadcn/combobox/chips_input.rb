# frozen_string_literal: true

# shadcn ComboboxChipsInput: the text field inside {Combobox::Chips} (`input`). Everything you pass reaches the input.
#
# @example
#   render Phlex::Shadcn::Combobox::ChipsInput.new(placeholder: "Add framework")
class Phlex::Shadcn::Combobox::ChipsInput < Phlex::Shadcn::Base
  include Phlex::Shadcn::Combobox::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "min-w-16 flex-1 outline-none"

  # @param disabled [Boolean] disables the input (and marks it `data-disabled`)
  # @param attrs [Hash] HTML attributes merged into the input (class goes through tailwind-merge)
  def initialize(disabled: false, **attrs)
    @disabled = disabled
    @attrs = attrs
    super()
  end

  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template
    model = root_model
    model.input_outside = true
    defaults = control_attrs(model).merge(id: model.id, class: CLASSES)
    defaults[:data] = defaults[:data].merge(slot: "combobox-chip-input", shadcn__combobox_part: "input")
    defaults[:data][:disabled] = "" if @disabled
    attrs = merge_attrs(defaults, @attrs)
    attrs[:disabled] = true if @disabled
    input(**attrs)
  end
end

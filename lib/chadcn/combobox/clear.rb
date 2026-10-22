# frozen_string_literal: true

# shadcn ComboboxClear: the button that clears the text and the selection. It exists while something is selected (the controller mounts
# and unmounts it, after its exit transition); the closed copy ships in an inert `<template>` so it can appear later.
#
# @example
#   render Chadcn::Combobox::Clear.new
class Chadcn::Combobox::Clear < Chadcn::Base
  include Chadcn::Combobox::Support

  # @param disabled [Boolean]
  # @param attrs [Hash] HTML attributes merged into the button (class goes through tailwind-merge)
  def initialize(disabled: false, **attrs)
    @disabled = disabled
    @attrs = attrs
    super()
  end

  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template
    model = root_model
    template(data: { chadcn__combobox_part: "clear-template" }) { clear_button(model, mounted: false) }
    clear_button(model, mounted: true) if model.selection.any?
  end

  private

  def clear_button(model, mounted:)
    disabled = model.disabled? || @disabled
    state = {}
    state.merge!(visible: "", **(model.open? ? { popup_open: "" } : {})) if mounted
    state[:disabled] = "" if disabled
    render Chadcn::InputGroup::Button.new(
      variant: "ghost", size: "icon-xs", "data-slot": "combobox-clear", tabindex: "-1", disabled: disabled,
      data: state.merge(chadcn__combobox_part: "clear"), **@attrs
    ) { render Chadcn::Icon.new("x", class: "pointer-events-none") }
  end
end

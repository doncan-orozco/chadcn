# frozen_string_literal: true

# shadcn ComboboxValue: the current selection as content. Renders no element (React passes `slot: "combobox-value"`, Base UI drops it):
# the selected label as bare text, the placeholder while nothing is selected, or what the block returns. The block receives the
# selected item (nil when none) in single mode and the Array of selected items in multiple mode.
#
# For the controller to rebuild the content after a client-side selection it ships inert `<template>` markers around the live content:
# one holding the block output for each item (and for no selection), and an end marker.
#
# @example Show the selection (single mode)
#   render(Chadcn::Combobox::Value.new(placeholder: "Select a framework"))
# @example Chips (multiple mode)
#   render(Chadcn::Combobox::Value.new) do |values|
#     values.each { |value| render(Chadcn::Combobox::Chip.new { value }) }
#     render Chadcn::Combobox::ChipsInput.new
#   end
class Chadcn::Combobox::Value < Chadcn::Base
  include Chadcn::Combobox::Support

  # @param placeholder [String, nil] shown while nothing is selected
  def initialize(placeholder: nil)
    @placeholder = placeholder
    super()
  end

  # @yieldparam selection [Object, Array, nil] the selected item (single) or items (multiple)
  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template(&block)
    model = root_model
    protos = block ? prototypes(model, &block) : {}
    # A block that renders nothing for any item (for example the parity harness' empty block) means "no content block".
    protos = {} if protos.values.all? { |html| html.strip.empty? }
    template(data: { shadcn__combobox_part: "value-start", placeholder: @placeholder.to_s, has_placeholder: (@placeholder.nil? ? "false" : "true") }) do
      protos.each { |key, html| template(data: { shadcn__combobox_part: "value-prototype", key: key }) { raw(safe(html)) } }
    end
    current(model, protos.any? ? block : nil)
    template(data: { shadcn__combobox_part: "value-end" })
  end

  private

  def current(model, block)
    return block.call(model.multiple? ? model.selection : model.selection.first) if block
    return plain(@placeholder.to_s) if model.selection.empty? && !@placeholder.nil?

    plain(model.selection.map { |item| model.label(item) }.join(", "))
  end

  # The block output for each possible selection (form value => HTML), read by the controller to build the content of a new selection.
  def prototypes(model, &)
    items = (model.flat_items + model.selection).uniq { |item| model.form_value(item) }
    protos = items.to_h { |item| [ model.form_value(item), capture { yield(model.multiple? ? [ item ] : item) } ] }
    protos[""] = capture { yield(nil) } unless model.multiple?
    protos
  end
end

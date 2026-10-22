# frozen_string_literal: true

# shadcn Combobox (Base UI `Combobox`, not Radix). Spec: dev/port/specs/combobox.md. Behavior: controllers/chadcn/combobox_controller.js.
# No JavaScript dependency: the Stimulus controller re-implements Base UI's state machine (open, highlight, filter, selection, chips)
# on the shared primitives and ranks with the scorer primitive.
#
# Root of the Combobox family (an input with a filterable popup list, single or multiple selection). Base UI's Root renders no element:
# this one renders a `display: contents` host that carries the `chadcn--combobox` controller, then the block, then the hidden inputs a
# native form submits. The closed popup ships in an inert `<template>` (see {Combobox::Content}).
#
# Items are Strings, Hashes (`value:`/`label:`, Symbol or String keys alike) or groups (`{ value:, items: [...] }`). Pass them as
# `items:` and let {Combobox::List} yield each one, or render {Combobox::Item}s yourself (static children, nothing is filtered).
#
# @example Explicit form
#   render Chadcn::Combobox.new(items: %w[Next.js SvelteKit Astro]) do
#     render Chadcn::Combobox::Input.new(placeholder: "Select a framework")
#     render Chadcn::Combobox::Content.new do
#       render(Chadcn::Combobox::Empty.new { "No items found." })
#       render Chadcn::Combobox::List.new do |item|
#         render(Chadcn::Combobox::Item.new(value: item) { item })
#       end
#     end
#   end
#
# @example Yielded-root helper form
#   render Chadcn::Combobox.new(items: %w[Next.js SvelteKit Astro], name: "framework") do |combobox|
#     combobox.input(placeholder: "Select a framework")
#     combobox.content do
#       combobox.empty { "No items found." }
#       combobox.list { |item| combobox.item(value: item) { item } }
#     end
#   end
#
# Events (Stimulus `dispatch`, bubbling, prefix `chadcn--combobox:`; `preventDefault()` is Base UI's `eventDetails.cancel()`):
# `value-change` (`{ value, reason }`), `open-change` (`{ open, reason }`), `input-value-change` (`{ inputValue, reason }`),
# `item-highlighted` (`{ value, index, reason }`, not cancelable) and `open-change-complete` (`{ open }`, not cancelable). With a
# controlled `value:`/`open:`/`input_value:` the event fires and the DOM waits for the caller to change the matching attribute.
#
# Generated helpers (each forwards `**attrs` and the block to the part):
#
# @!method input(**attrs, &block)
#   Same as `render Combobox::Input.new(**attrs), &block`.
# @!method trigger(**attrs, &block)
#   Same as `render Combobox::Trigger.new(**attrs), &block`.
# @!method clear(**attrs, &block)
#   Same as `render Combobox::Clear.new(**attrs), &block`.
# @!method value(**attrs, &block)
#   Same as `render Combobox::Value.new(**attrs), &block`.
# @!method content(**attrs, &block)
#   Same as `render Combobox::Content.new(**attrs), &block`.
# @!method list(**attrs, &block)
#   Same as `render Combobox::List.new(**attrs), &block`.
# @!method item(**attrs, &block)
#   Same as `render Combobox::Item.new(**attrs), &block`.
# @!method group(**attrs, &block)
#   Same as `render Combobox::Group.new(**attrs), &block`.
# @!method label(**attrs, &block)
#   Same as `render Combobox::Label.new(**attrs), &block`.
# @!method collection(**attrs, &block)
#   Same as `render Combobox::Collection.new(**attrs), &block`.
# @!method empty(**attrs, &block)
#   Same as `render Combobox::Empty.new(**attrs), &block`.
# @!method separator(**attrs, &block)
#   Same as `render Combobox::Separator.new(**attrs), &block`.
# @!method chips(**attrs, &block)
#   Same as `render Combobox::Chips.new(**attrs), &block`.
# @!method chip(**attrs, &block)
#   Same as `render Combobox::Chip.new(**attrs), &block`.
# @!method chips_input(**attrs, &block)
#   Same as `render Combobox::ChipsInput.new(**attrs), &block`.
class Chadcn::Combobox < Chadcn::Base
  # Default of `limit:`: render every match. A named constant keeps the YARD-rendered signature identical on every Ruby.
  # @api private
  NO_LIMIT = -1
  # @api private
  CONTEXT_KEY = :shadcn_combobox_root
  # @api private
  SEQUENCE_KEY = :shadcn_combobox_sequence

  # Base UI `visuallyHiddenInput` / `visuallyHidden`, written exactly as React serializes them.
  #
  # @api private
  VISUALLY_HIDDEN_INPUT = "clip-path: inset(50%); overflow: hidden; white-space: nowrap; border: 0px; padding: 0px; width: 1px; height: 1px; margin: -1px; position: absolute;"
  # @api private
  VISUALLY_HIDDEN = "clip-path: inset(50%); overflow: hidden; white-space: nowrap; border: 0px; padding: 0px; width: 1px; height: 1px; margin: 0px; position: fixed; top: 0px; left: 0px;"

  # @param items [Array, nil] Strings, Hashes (`value:`/`label:`, extra keys allowed) or groups (`{ value:, items: [...] }`); nil
  #   renders the items as static children and filters nothing
  # @param multiple [Boolean] selection mode "multiple" (chips)
  # @param value [Object, nil] controlled selection (an item; an Array when multiple); nil leaves the selection uncontrolled
  # @param default_value [Object, nil] initial selection when uncontrolled
  # @param input_value [String, nil] controlled text of the input
  # @param default_input_value [String, nil] initial text of the input (single mode: the label of the selection)
  # @param open [Boolean, nil] controlled popup state
  # @param default_open [Boolean] initial popup state when uncontrolled
  # @param name [String, nil] form field name (hidden input(s)); multiple mode submits one hidden input per selected value
  # @param form [String, nil] id of the owning form
  # @param auto_complete [String, nil] autocomplete attribute of the hidden input
  # @param id [String, nil] id of the input; items are `<id>-<index>` and the hidden input `<id>-hidden-input`
  # @param disabled [Boolean]
  # @param read_only [Boolean] the popup opens and browses but never selects
  # @param required [Boolean]
  # @param auto_highlight [Boolean, String, Symbol] highlight the first match while typing; "always" also on open
  # @param keep_highlight [Boolean] keep the highlight when the pointer leaves an item
  # @param highlight_item_on_hover [Boolean]
  # @param loop_focus [Boolean] wrap the keyboard highlight around the ends
  # @param open_on_input_click [Boolean] open the popup when the input is pressed
  # @param modal [Boolean] backdrop and page scroll lock while open; focus is not trapped (recorded deviation)
  # @param limit [Integer] maximum number of rendered matches (-1: all)
  # @param submit_on_item_click [Boolean] submit the form after an item press
  # @param filter ["fuzzy", "contains", nil] "fuzzy" ranks with the scorer primitive, "contains" is Base UI's collator substring
  #   match, nil disables filtering
  # @param locale [String, nil] collator locale of the "contains" filter
  # @param item_to_string_label [#call, nil] item => label, evaluated on the server
  # @param item_to_string_value [#call, nil] item => form value, evaluated on the server
  # @param item_equal_to_value [#call, nil] (item, value) => Boolean, evaluated on the server (default `==`)
  def initialize(items: nil, multiple: false, value: nil, default_value: nil, input_value: nil, default_input_value: nil, open: nil,
                 default_open: false, name: nil, form: nil, auto_complete: nil, id: nil, disabled: false, read_only: false,
                 required: false, auto_highlight: false, keep_highlight: false, highlight_item_on_hover: true, loop_focus: true,
                 open_on_input_click: true, modal: false, limit: NO_LIMIT, submit_on_item_click: false, filter: "fuzzy", locale: nil,
                 item_to_string_label: nil, item_to_string_value: nil, item_equal_to_value: nil)
    @options = {
      items: items, multiple: multiple, value: value, default_value: default_value, input_value: input_value,
      default_input_value: default_input_value, open: open, default_open: default_open, name: name, form: form,
      auto_complete: auto_complete, id: id, disabled: disabled, read_only: read_only, required: required,
      auto_highlight: auto_highlight, keep_highlight: keep_highlight, highlight_item_on_hover: highlight_item_on_hover,
      loop_focus: loop_focus, open_on_input_click: open_on_input_click, modal: modal, limit: limit,
      submit_on_item_click: submit_on_item_click, filter: filter, locale: locale, item_to_string_label: item_to_string_label,
      item_to_string_value: item_to_string_value, item_equal_to_value: item_equal_to_value
    }
    super()
  end

  # @yieldparam combobox [Combobox] the root, exposing the generated part helpers
  # @return [void]
  def view_template
    previous = context[CONTEXT_KEY]
    sequence = context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1
    model = context[CONTEXT_KEY] = Model.new(@options, sequence)
    div(style: "display: contents", data: host_data(model)) do
      yield self if block_given?
      hidden_inputs(model)
    end
  ensure
    context[CONTEXT_KEY] = previous
  end

  private

  def host_data(model)
    {
      controller: "chadcn--combobox",
      chadcn__combobox_config_value: json(config(model)),
      chadcn__combobox_selected_value: json(model.selected_keys),
      chadcn__combobox_open_value: model.open?.to_s,
      chadcn__combobox_input_value_value: model.input_value
    }
  end

  def config(model)
    {
      id: model.id, multiple: model.multiple?, disabled: model.disabled?, readOnly: model.read_only?, required: model.required?,
      name: model.name, form: model.form, autoHighlight: model.auto_highlight, keepHighlight: model.keep_highlight?,
      highlightItemOnHover: model.highlight_item_on_hover?, loopFocus: model.loop_focus?, openOnInputClick: model.open_on_input_click?,
      modal: model.modal?, limit: model.limit, submitOnItemClick: model.submit_on_item_click?, filter: model.filter,
      locale: model.locale, hasItems: model.items?, items: model.registry, extras: model.extras, valueControlled: model.value_controlled?,
      openControlled: model.open_controlled?, inputValueControlled: model.input_value_controlled?,
      inputValueGiven: model.input_value_given?
    }
  end

  # Base UI Root: the autofill-aware hidden input, then (multiple mode with a name) one hidden input per selected value.
  def hidden_inputs(model)
    named = !model.name.nil? && !model.multiple?
    attrs = {
      tabindex: "-1", aria: { hidden: "true" }, value: model.multiple? ? "" : model.selected_keys.first.to_s,
      style: named ? VISUALLY_HIDDEN_INPUT : VISUALLY_HIDDEN, form: model.form, autocomplete: model.auto_complete,
      disabled: model.disabled?, readonly: model.read_only?, data: { chadcn__combobox_part: "hidden-input" },
      required: model.required? && !(model.multiple? && model.selection.any?)
    }
    attrs[:id] = "#{model.id}-hidden-input" unless named
    attrs[:name] = model.name if named
    native_input(**attrs)
    return unless model.multiple? && model.name

    model.selected_keys.each do |key|
      native_input(type: "hidden", form: model.form, name: model.name, value: key, disabled: model.disabled?,
                   data: { chadcn__combobox_part: "form-value" })
    end
  end

  # The generated `input` helper (Combobox::Input) shadows Phlex's `<input>` element method on this class: call the element directly.
  def native_input(**attrs) = Phlex::HTML::VoidElements.instance_method(:input).bind_call(self, **attrs)
end

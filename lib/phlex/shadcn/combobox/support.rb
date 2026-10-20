# frozen_string_literal: true

# What the Combobox parts share: the model pushed by the root, the state data attributes Base UI puts on its input, trigger and
# clear button, and the item indicator markup.
#
# @api private
module Phlex::Shadcn::Combobox::Support
  # The check mark of a selected item (src ComboboxItem: `ComboboxPrimitive.ItemIndicator` with this `span`).
  INDICATOR_CLASS = "pointer-events-none absolute right-2 flex size-4 items-center justify-center"
  # Classes of the icon inside the indicator.
  INDICATOR_ICON_CLASS = "pointer-events-none size-4 pointer-coarse:size-5"

  private

  def root_model
    context[Phlex::Shadcn::Combobox::CONTEXT_KEY] or raise ArgumentError, "#{self.class.name} must be used within Combobox"
  end

  # Whether the filtered list is empty at first paint: no `items:` (static children), or an empty list.
  def list_empty?(model) = !model.items? || model.flat_items.empty?

  # Base UI `triggerStateAttributesMapping` (+ `disabled`, `readonly`): state attributes of the input and the trigger.
  def state_data(model, open: model.open?, disabled: false)
    data = {}
    if open
      data[:popup_open] = ""
      data[:pressed] = ""
    end
    data[:list_empty] = "" if list_empty?(model)
    data[:disabled] = "" if disabled || model.disabled?
    data[:readonly] = "" if model.read_only?
    data
  end

  # Attributes Base UI gives every input that controls the popup (the visible input and the chips input).
  def control_attrs(model, open: model.open?, value: model.input_value)
    attrs = {
      autocomplete: "off", spellcheck: "false", autocorrect: "off", autocapitalize: "none", role: "combobox",
      aria: { expanded: open.to_s, haspopup: "listbox", autocomplete: model.read_only? ? "none" : "list",
              controls: (model.list_id if open), required: (model.required? ? "true" : nil),
              readonly: (model.read_only? ? "true" : nil) },
      value: value, data: state_data(model, open: open)
    }
    attrs[:readonly] = true if model.read_only?
    attrs
  end

  # The indicator `span` of a selected item.
  def render_indicator(selected: true)
    span(class: INDICATOR_CLASS, data: { slot: "combobox-item-indicator", selected: (selected ? "" : nil) }, aria: { hidden: "true" }) do
      render Phlex::Shadcn::Icon.new("check", class: INDICATOR_ICON_CLASS)
    end
  end

  def render_part(tag_name, as_child, attrs, &)
    return render_as_child(as_child, **attrs, &) if as_child

    tag(tag_name, **attrs, &)
  end
end

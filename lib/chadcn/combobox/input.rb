# frozen_string_literal: true

# shadcn ComboboxInput: the text field of the combobox, composed like shadcn does it (an InputGroup with the input, an addon holding
# the trigger and the clear button, and your block). `class:` reaches the InputGroup; every other attribute reaches the `<input>`.
# Inside {Combobox::Content} it is the search field of a popup that opens from a standalone {Combobox::Trigger}.
#
# @example
#   render Chadcn::Combobox::Input.new(placeholder: "Select a framework", show_clear: true)
class Chadcn::Combobox::Input < Chadcn::Base
  include Chadcn::Combobox::Support

  # @param disabled [Boolean] disables the rendered `<input>`, the trigger and the clear button (not the combobox)
  # @param show_trigger [Boolean] render the chevron button
  # @param show_clear [Boolean] render the clear button (it shows while something is selected)
  # @param attrs [Hash] HTML attributes merged into the `<input>`; `class:` goes to the InputGroup
  def initialize(disabled: false, show_trigger: true, show_clear: false, **attrs)
    @disabled = disabled
    @show_trigger = show_trigger
    @show_clear = show_clear
    @attrs = attrs
    super()
  end

  # @yield extra InputGroup children (an {Chadcn::InputGroup::Addon}, for example)
  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template(&block)
    model = root_model
    model.input_outside = true unless model.in_popup
    render Chadcn::InputGroup.new(class: cn("w-auto", @attrs[:class])) do |group|
      dismiss_button(model)
      group.input(**input_attrs(model))
      group.addon(align: "inline-end") do
        render_trigger if @show_trigger
        render Chadcn::Combobox::Clear.new(disabled: @disabled) if @show_clear
      end
      block&.call(group)
    end
  end

  private

  # Base UI renders the dismiss button before the input while a modal focus manager is open (input outside the popup).
  def dismiss_button(model)
    return if model.in_popup || !model.open?

    span(role: "button", aria: { label: "Dismiss" }, style: Chadcn::Combobox::VISUALLY_HIDDEN_INPUT,
         data: { chadcn__combobox_part: "dismiss-start" })
  end

  def render_trigger
    render Chadcn::InputGroup::Button.new(
      size: "icon-xs", variant: "ghost", as_child: Chadcn::Combobox::Trigger.new, "data-slot": "input-group-button",
      class: "group-has-data-[slot=combobox-clear]/input-group:hidden data-pressed:bg-transparent", disabled: @disabled
    )
  end

  # Inside the popup the popup is open by definition, and its field starts empty (Base UI clears it when it mounts).
  def input_attrs(model)
    defaults = if model.in_popup
      control_attrs(model, open: true, value: model.input_value_given? ? model.input_value : "").merge(id: "#{model.id}-input")
    else
      control_attrs(model).merge(id: model.id)
    end
    defaults[:data] = defaults[:data].merge(chadcn__combobox_part: "input")
    attrs = merge_attrs(defaults, @attrs.except(:class))
    attrs[:disabled] = true if @disabled
    attrs
  end
end

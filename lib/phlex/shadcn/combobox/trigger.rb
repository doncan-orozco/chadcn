# frozen_string_literal: true

# shadcn ComboboxTrigger: the chevron button of {Combobox::Input} (rendered through `InputGroup::Button`'s `as_child:`), or, used on its
# own, the button that shows the selection and opens a popup holding the search {Combobox::Input}. Renders the chevron after the block.
#
# @example A button that opens a searchable popup
#   render(Phlex::Shadcn::Combobox::Trigger.new(class: "w-64 justify-between font-normal")) { render Phlex::Shadcn::Combobox::Value.new }
class Phlex::Shadcn::Combobox::Trigger < Phlex::Shadcn::Base
  include Phlex::Shadcn::Combobox::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "[&_svg:not([class*='size-'])]:size-4"

  # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Base UI `render`; Radix Slot merge)
  # @param disabled [Boolean]
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(as_child: false, disabled: false, **attrs)
    @as_child = as_child
    @disabled = disabled
    @attrs = attrs
    super()
  end

  # @yield the button content, rendered before the chevron
  # @return [void]
  # @raise [ArgumentError] when rendered outside Combobox
  def view_template(&block)
    model = root_model
    attrs = merge_attrs(defaults(model), @attrs.except(:disabled))
    attrs[:disabled] = true if disabled?(model)
    render_part(:button, @as_child, attrs) do
      block&.call
      render Phlex::Shadcn::Icon.new("chevron-down", class: "pointer-events-none size-4 text-muted-foreground",
                                                     "data-slot": "combobox-trigger-icon")
    end
  end

  private

  def disabled?(model) = model.disabled? || @disabled || !!@attrs[:disabled]

  def defaults(model)
    popup_mode = !model.input_outside
    data = state_data(model, disabled: disabled?(model)).merge(slot: "combobox-trigger", shadcn__combobox_part: "trigger")
    data[:placeholder] = "" if model.selection.empty?
    {
      type: "button", tabindex: popup_mode ? "0" : "-1", class: CLASSES, data: data,
      aria: { expanded: model.open?.to_s, haspopup: popup_mode ? "dialog" : "listbox", controls: controls(model, popup_mode),
              required: (popup_mode && model.required? ? "true" : nil), readonly: (popup_mode && model.read_only? ? "true" : nil) }
    }.merge(popup_mode ? { id: model.id, role: "combobox" } : {})
  end

  def controls(model, popup_mode)
    return unless model.open?

    popup_mode ? model.popup_id : model.list_id
  end
end

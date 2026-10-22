# frozen_string_literal: true

# Renders a +button+ with +role="combobox"+ and the +data-controller="chadcn--select"+ wiring (values mirror the root state), plus
# a trailing chevron icon. When the root has +name:+ or +form:+ it also renders the hidden native +select+ after the button; the
# controller keeps that select only when the Trigger is inside a form or +form:+ is set, so +name:+ alone outside a form submits
# nothing. Renders nothing during the root's collect pass. Hosts the +chadcn--select+ controller. +as_child:+ is not offered (the
# React original throws for it).
#
# @example
#   select.trigger(size: :sm, class: "w-40") { select.value(placeholder: "Pick") }
class Chadcn::Select::Trigger < Chadcn::Base
  include Chadcn::Select::Support

  # @return [String] Tailwind classes of the button
  CLASSES = "flex w-fit items-center justify-between gap-2 rounded-md border border-input bg-transparent px-3 py-2 text-sm whitespace-nowrap shadow-xs transition-[color,box-shadow] outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 data-[placeholder]:text-muted-foreground data-[size=default]:h-9 data-[size=sm]:h-8 *:data-[slot=select-value]:line-clamp-1 *:data-[slot=select-value]:flex *:data-[slot=select-value]:items-center *:data-[slot=select-value]:gap-2 dark:bg-input/30 dark:hover:bg-input/50 dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 [&_svg:not([class*='text-'])]:text-muted-foreground"
  # @return [String] inline style that hides the native select visually while keeping it submittable
  VISUALLY_HIDDEN = "position: absolute; border: 0px; width: 1px; height: 1px; padding: 0px; margin: -1px; overflow: hidden; clip: rect(0px, 0px, 0px, 0px); white-space: nowrap; overflow-wrap: normal;"

  # @param size [String, Symbol] +"default"+ or +"sm"+ (written to +data-size+, which the classes style; not validated); +nil+ falls back to +"default"+
  # @param disabled [Boolean] disables the button (also disabled when the root is)
  # @param attrs [Hash] HTML attributes merged into the element (+class+ is merged with Tailwind conflict resolution, +data+/+aria+ deep-merged, caller wins)
  # @return [void]
  # @raise [ArgumentError] at construction when +as_child:+ is passed (not supported, as in React)
  def initialize(size: "default", disabled: false, **attrs)
    raise ArgumentError, "#{self.class.name} does not support as_child" if attrs.key?(:as_child)

    @size = normalize_option(size) || "default"
    @disabled = disabled
    @attrs = attrs
    super()
  end

  # @yield optional block rendered before the chevron icon (usually {Chadcn::Select::Value})
  # @return [void]
  # @raise [ArgumentError] at render when used outside {Chadcn::Select}
  def view_template
    return if collecting?

    state = select_state
    button(**merge_attrs(attributes(state), @attrs)) do
      yield if block_given?
      render Chadcn::Icon.new("chevron-down", class: "size-4 opacity-50")
    end
    native_select(state) if state[:name] || state[:form]
  end

  private

  def attributes(state)
    open = state[:open]
    disabled = state[:disabled] || @disabled
    {
      type: "button", role: "combobox", dir: state[:dir], disabled:, class: CLASSES,
      aria: { controls: (content_id(state) if open), expanded: open.to_s, required: state[:required], autocomplete: "none" },
      data: {
        slot: "select-trigger", size: @size, state: open ? "open" : "closed", disabled: (disabled ? "" : nil),
        placeholder: (blank_value? ? "" : nil), controller: "chadcn--select", **values(state)
      }
    }
  end

  def values(state)
    {
      chadcn__select_open_value: state[:open].to_s, chadcn__select_controlled_open_value: state[:controlled_open].to_s,
      chadcn__select_value_value: state[:value].to_s, chadcn__select_controlled_value_value: state[:controlled_value].to_s,
      chadcn__select_disabled_value: state[:disabled].to_s, chadcn__select_dir_value: state[:dir], chadcn__select_content_id_value: content_id(state),
      chadcn__select_name_value: state[:name], chadcn__select_form_value: state[:form], chadcn__select_auto_complete_value: state[:auto_complete]
    }
  end

  def content_id(state) = "#{state[:base]}-content"

  # SelectBubbleInput: the controller adopts it inside a form (or with +form:+) and removes it elsewhere.
  def native_select(state)
    value = state[:value].to_s
    select(aria: { hidden: "true" }, tabindex: -1, name: state[:name], form: state[:form], autocomplete: state[:auto_complete],
           required: state[:required] == true, disabled: state[:disabled], style: VISUALLY_HIDDEN) do
      option(value: "") if value.empty? && state[:known].none? { |item| item[:value].empty? }
      state[:known].each do |item|
        option(value: item[:value], disabled: item[:disabled], selected: item[:value] == value) { item[:text] }
      end
    end
  end
end

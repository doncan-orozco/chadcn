# frozen_string_literal: true

# shadcn CommandInput: the search field (wrapper `div` + search icon + cmdk's `input`).
#
# `class:` and `**attrs` reach the `<input>`, never the wrapper. The attributes cmdk sets after the caller props
# (`role`, `type`, `id`, `autocomplete`, `aria-controls`...) cannot be overridden.
#
# @example
#   render Chadcn::Command::Input.new(placeholder: "Type a command or search...")
class Chadcn::Command::Input < Chadcn::Base
  include Chadcn::Command::Support

  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "flex h-10 w-full rounded-md bg-transparent py-3 text-sm outline-hidden placeholder:text-muted-foreground disabled:cursor-not-allowed disabled:opacity-50"
  # Tailwind classes of the wrapper around the input, as in the shadcn source.
  #
  # @return [String]
  WRAPPER_CLASSES = "flex h-9 items-center gap-2 border-b px-3"

  # @param value [String, nil] controlled search (typing does not change it; listen to `search-change`); nil: uncontrolled
  # @param attrs [Hash] HTML attributes merged into the `input` (class goes through tailwind-merge)
  def initialize(value: nil, **attrs)
    @value = value
    @attrs = attrs
    super()
  end

  # @return [void]
  # @raise [ArgumentError] when rendered outside Command
  def view_template
    root = root_context
    div(class: WRAPPER_CLASSES, data: { slot: "command-input-wrapper" }) do
      render Chadcn::Icon.new("search", class: "size-4 shrink-0 opacity-50")
      input(**input_attrs(root))
    end
  end

  private

  def input_attrs(root)
    attrs = merge_attrs({ class: CLASSES, data: { slot: "command-input" } }, @attrs)
    attrs = with_forced(
      attrs,
      { "cmdk-input": "", autocomplete: "off", autocorrect: "off", spellcheck: "false", role: "combobox", id: "#{root[:base]}-input",
        type: "text", value: @value.to_s },
      aria: { autocomplete: "list", expanded: "true", controls: "#{root[:base]}-list", labelledby: "#{root[:base]}-label" }
    )
    @value.nil? ? attrs : with_forced(attrs, {}, data: { chadcn__command_search: @value.to_s })
  end
end

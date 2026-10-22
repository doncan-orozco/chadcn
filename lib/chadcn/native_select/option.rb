# frozen_string_literal: true

class Chadcn::NativeSelect
  # An `<option>`. Renders `selected` when its `value:` matches the parent's `value`/`default_value`
  # (only the first match in single mode). An explicit `selected:` attribute wins.
  #
  # @example
  #   select.option(value: "a") { "Alpha" }
  class Option < Chadcn::Base
    # @param attrs [Hash] HTML attributes for the `<option>` (`value:`, `disabled:`, `selected:`, `class:`)
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    # @yield the option label
    # @return [void]
    def view_template(&)
      attrs = merge_attrs({ class: "bg-[Canvas] text-[CanvasText]", data: { slot: "native-select-option" } }, @attrs)
      attrs[:selected] = selected? unless @attrs.key?(:selected)
      option(**attrs, &)
    end

    private

    # Single mode marks only the first match, like React updateOptions.
    def selected?
      state = context[Chadcn::NativeSelect::CONTEXT_KEY]
      return false if state.nil? || state[:values].empty?

      value = (@attrs[:value] || "").to_s
      return false unless state[:values].include?(value)
      return true if state[:multiple]
      return false if state[:taken]

      state[:taken] = true
    end
  end
end

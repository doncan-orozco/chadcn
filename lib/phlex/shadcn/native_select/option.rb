# frozen_string_literal: true

class Phlex::Shadcn::NativeSelect
  class Option < Phlex::Shadcn::Base
    def initialize(**attrs)
      @attrs = attrs
      super()
    end

    def view_template(&)
      attrs = merge_attrs({ class: "bg-[Canvas] text-[CanvasText]", data: { slot: "native-select-option" } }, @attrs)
      attrs[:selected] = selected? unless @attrs.key?(:selected)
      option(**attrs, &)
    end

    private

    # Single mode marks only the first match, like React updateOptions.
    def selected?
      state = context[Phlex::Shadcn::NativeSelect::CONTEXT_KEY]
      return false if state.nil? || state[:values].empty?

      value = (@attrs[:value] || "").to_s
      return false unless state[:values].include?(value)
      return true if state[:multiple]
      return false if state[:taken]

      state[:taken] = true
    end
  end
end

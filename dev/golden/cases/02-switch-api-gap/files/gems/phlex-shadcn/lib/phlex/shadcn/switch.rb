# frozen_string_literal: true

module Components
  module V2
    # Classes and slots are faithful, but the `size` option and `data-size` are missing.
    class Switch < Components::Base
      ROOT = "peer group/switch inline-flex shrink-0 items-center rounded-full border border-transparent shadow-xs transition-all outline-none focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:cursor-not-allowed disabled:opacity-50 data-[size=default]:h-[1.15rem] data-[size=default]:w-8 data-[size=sm]:h-3.5 data-[size=sm]:w-6 data-[state=checked]:bg-primary data-[state=unchecked]:bg-input dark:data-[state=unchecked]:bg-input/80"
      THUMB = "pointer-events-none block rounded-full bg-background ring-0 transition-transform group-data-[size=default]/switch:size-4 group-data-[size=sm]/switch:size-3 data-[state=checked]:translate-x-[calc(100%-2px)] data-[state=unchecked]:translate-x-0 dark:data-[state=checked]:bg-primary-foreground dark:data-[state=unchecked]:bg-foreground"

      def initialize(checked: false, **attrs)
        @checked = checked
        @attrs = attrs
      end

      def view_template
        state = @checked ? "checked" : "unchecked"
        button(type: "button", role: "switch", aria: { checked: @checked }, data: { slot: "switch", state: state }, class: cn(ROOT, @attrs[:class]), **attrs_without_class) do
          span(data: { slot: "switch-thumb", state: state }, class: THUMB)
        end
      end
    end
  end
end

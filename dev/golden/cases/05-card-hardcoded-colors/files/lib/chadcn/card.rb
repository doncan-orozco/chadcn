# frozen_string_literal: true

module Components
  module V2
    # Seeded: hardcoded palette/hex instead of tokens, 2024-era shadow, and only the root part exists.
    class Card < Components::Base
      def initialize(**attrs)
        @attrs = attrs
      end

      def view_template(&block)
        div(data: { slot: "card" }, class: cn("flex flex-col gap-6 rounded-xl border border-[#e5e7eb] bg-white text-gray-900 py-6 shadow dark:bg-zinc-900 dark:text-zinc-50", @attrs[:class]), **attrs_without_class, &block)
      end
    end
  end
end

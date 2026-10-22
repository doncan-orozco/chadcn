# frozen_string_literal: true

module Components
  module V2
    # Faithful port of shadcn/ui new-york-v4 badge.tsx (false-positive control).
    class Badge < Components::Base
      # An apostrophe in prose (it's a comment) must not pair with a later quote and swallow code.
      NOTE = 'single quoted'
      WORDS = %w[default secondary].freeze

      BASE = "inline-flex w-fit shrink-0 items-center justify-center gap-1 overflow-hidden rounded-full border border-transparent px-2 py-0.5 text-xs font-medium whitespace-nowrap transition-[color,box-shadow] focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&>svg]:pointer-events-none [&>svg]:size-3"

      VARIANTS = {
        "default" => "bg-primary text-primary-foreground [a&]:hover:bg-primary/90",
        "secondary" => "bg-secondary text-secondary-foreground [a&]:hover:bg-secondary/90",
        "destructive" => "bg-destructive text-white focus-visible:ring-destructive/20 dark:bg-destructive/60 dark:focus-visible:ring-destructive/40 [a&]:hover:bg-destructive/90",
        "outline" => "border-border text-foreground [a&]:hover:bg-accent [a&]:hover:text-accent-foreground",
        "ghost" => "[a&]:hover:bg-accent [a&]:hover:text-accent-foreground",
        "link" => "text-primary underline-offset-4 [a&]:hover:underline"
      }.freeze

      def self.variants(variant: "default")
        [BASE, VARIANTS.fetch(variant.to_s)].join(" ")
      end

      def initialize(variant: "default", as_child: false, **attrs)
        @variant = variant.to_s
        @as = as_child.is_a?(Symbol) ? as_child : :span
        @attrs = attrs
      end

      def view_template(&block)
        public_send(
          @as,
          data: { slot: "badge", variant: @variant },
          class: cn(self.class.variants(variant: @variant), @attrs[:class]),
          **attrs_without_class,
          &block
        )
      end
    end
  end
end

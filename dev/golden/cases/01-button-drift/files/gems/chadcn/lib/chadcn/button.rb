module Components
  module V2
    # Phlex translation of shadcn/ui Button
    # https://github.com/shadcn/ui/blob/main/components/button.tsx
    # Uses the same Tailwind classes produced by the React component
    # and exposes variant/size options for styling.
    class Button < Components::Base
      # @param variant [Symbol] one of :default, :destructive, :outline, :secondary, :ghost, :link
      # @param size [Symbol] one of :default, :sm, :lg, :icon
      # @param as [Symbol] HTML element to render (defaults to :button)
      # @param attrs [Hash] additional HTML attributes (including :class)
      def initialize(variant: :default, size: :default, as: :button, **attrs)
        @variant = variant
        @size = size
        @as = as
        @attrs = attrs
      end

      def view_template(&block)
        public_send(@as, class: merged_classes, **attrs_without_class, &block)
      end

      private

      def classes
        [
          base_classes,
          variant_classes.fetch(@variant, variant_classes[:default]),
          size_classes.fetch(@size, size_classes[:default])
        ].compact.join(" ")
      end

      def base_classes
        # copied exactly from React buttonVariants default string
        "inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-sm font-medium transition-colors \
        focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-50 \
        [&_svg]:pointer-events-none [&_svg]:size-4 [&_svg]:shrink-0"
      end

      def variant_classes
        {
          default: "bg-primary text-primary-foreground shadow hover:bg-primary/90",
          destructive: "bg-destructive text-destructive-foreground shadow-sm hover:bg-destructive/90",
          outline: "border border-input bg-background shadow-sm hover:bg-accent hover:text-accent-foreground",
          secondary: "bg-secondary text-secondary-foreground shadow-sm hover:bg-secondary/80",
          ghost: "hover:bg-accent hover:text-accent-foreground",
          link: "text-primary underline-offset-4 hover:underline"
        }
      end

      def size_classes
        {
          default: "h-9 px-4 py-2",
          sm: "h-8 rounded-md px-3 text-xs",
          lg: "h-10 rounded-md px-8",
          icon: "h-11 w-11"
        }
      end
    end
  end
end

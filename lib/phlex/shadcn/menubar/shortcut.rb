# frozen_string_literal: true

# A keyboard-shortcut hint, a plain +span+ in the oracle (no Radix primitive, so no +as_child+).
#
# @example
#   bar.item { plain "New"; bar.shortcut { "Ctrl+N" } }
class Phlex::Shadcn::Menubar::Shortcut < Phlex::Shadcn::Base
  # @return [String] default Tailwind classes; the +class:+ you pass is merged on top
  CLASSES = "ml-auto text-xs tracking-widest text-muted-foreground"

  # @param attrs [Hash] extra HTML attributes; +class+ is merged with {CLASSES} (yours wins Tailwind conflicts), +data+/+aria+ are deep merged
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  def view_template(&)
    span(**merge_attrs({ class: CLASSES, data: { slot: "menubar-shortcut" } }, @attrs), &)
  end
end

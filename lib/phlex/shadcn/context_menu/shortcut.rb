# frozen_string_literal: true

# shadcn ContextMenuShortcut: a plain +span+ in the oracle (no Radix primitive, so there is no +as_child+ option: an +as_child:+
# keyword lands in +attrs+ and is rendered as a literal HTML attribute) that shows a keyboard hint at the end of an item.
#
# @example
#   menu.item do
#     plain "Back"
#     menu.shortcut { "Cmd+[" }
#   end
class Phlex::Shadcn::ContextMenu::Shortcut < Phlex::Shadcn::Base
  # @return [String] the default Tailwind classes (shadcn new-york-v4)
  CLASSES = "ml-auto text-xs tracking-widest text-muted-foreground"

  # @param attrs [Hash] HTML attributes for the span; +class+ is merged with the defaults through tailwind-merge, +data+ and
  #   +aria+ are deep-merged (the caller wins)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the text of the hint
  # @return [void]
  def view_template(&)
    span(**merge_attrs({ class: CLASSES, data: { slot: "context-menu-shortcut" } }, @attrs), &)
  end
end

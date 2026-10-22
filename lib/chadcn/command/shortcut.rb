# frozen_string_literal: true

# shadcn CommandShortcut: the right-aligned keyboard hint of an item (`span`).
#
# @example
#   render(Chadcn::Command::Shortcut.new { "⌘P" })
class Chadcn::Command::Shortcut < Chadcn::Base
  # Tailwind classes of the element, as in the shadcn source.
  #
  # @return [String]
  CLASSES = "ml-auto text-xs tracking-widest text-muted-foreground"

  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the shortcut text
  # @return [void]
  def view_template(&)
    span(**merge_attrs({ class: CLASSES, data: { slot: "command-shortcut" } }, @attrs), &)
  end
end

# frozen_string_literal: true

# A plain +span+ in the oracle (no Radix primitive, so no as_child): the keyboard shortcut hint at the end of an item.
#
# @example
#   menu.item do
#     plain "Save"
#     menu.shortcut { "Ctrl+S" }
#   end
class Phlex::Shadcn::DropdownMenu::Shortcut < Phlex::Shadcn::Base
  # Default Tailwind classes of the shortcut (merged with +class:+).
  #
  # @return [String]
  CLASSES = "ml-auto text-xs tracking-widest text-muted-foreground"

  # @param attrs [Hash] extra HTML attributes merged over the defaults: +class:+ is merged with tailwind_merge,
  #   +data:+ and +aria:+ hashes are deep merged
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the shortcut text
  # @return [void]
  def view_template(&)
    span(**merge_attrs({ class: CLASSES, data: { slot: "dropdown-menu-shortcut" } }, @attrs), &)
  end
end

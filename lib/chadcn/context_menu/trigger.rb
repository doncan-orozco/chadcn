# frozen_string_literal: true

using Chadcn::Values::Refinements

# Radix ContextMenuTrigger: a +span+ without classes, ids or aria that hosts the +shadcn--context-menu+ controller. The menu opens
# at the pointer on +contextmenu+ and, for touch or pen pointers, on a long press. It sets +data-state+ (+open+ or +closed+) and
# the controller values from the root; with +disabled: true+ it renders +data-disabled+ and the controller ignores the gesture.
# A caller +class+ is emitted verbatim (no tailwind-merge) and a caller +style+ is appended after
# +-webkit-touch-callout: none+.
#
# @example
#   menu.trigger(class: "flex h-40 w-72 items-center justify-center rounded-md border border-dashed") { "Right click here" }
class Chadcn::ContextMenu::Trigger < Chadcn::Base
  include Chadcn::ContextMenu::Support

  # @param disabled [Boolean] +true+ renders +data-disabled=""+ on the span (default +false+)
  # @param as_child [false, Symbol, String, Chadcn::Base] +false+ renders the default element; a tag Symbol/String
  #   or a component instance renders that element/component instead, with this part's attributes merged into it
  #   (Radix Slot)
  # @param attrs [Hash] HTML attributes for the span; +data+ and +aria+ are deep-merged (the caller wins)
  def initialize(disabled: false, as_child: false, **attrs)
    @disabled = disabled
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the content of the area that opens the menu
  # @return [void]
  # @raise [ArgumentError] when not rendered within a {Chadcn::ContextMenu}
  def view_template(&)
    root = root_context
    attrs = merge_attrs({
                          data: {
                            slot: "context-menu-trigger", state: root[:open] ? "open" : "closed", disabled: (@disabled ? "" : nil),
                            controller: "shadcn--context-menu", **values(root)
                          }
                        }, @attrs.except(:style))
    attrs = verbatim_class(attrs, @attrs)
    attrs[:style] = [ "-webkit-touch-callout: none", style_string(@attrs[:style]) ].reject_blank.join("; ")
    render_part(:span, @as_child, attrs, &)
  end

  private

  def values(root)
    {
      shadcn__context_menu_open_value: root[:open].to_s,
      shadcn__context_menu_controlled_value: root[:controlled].to_s,
      shadcn__context_menu_modal_value: root[:modal].to_s,
      shadcn__context_menu_dir_value: root[:dir],
      shadcn__context_menu_template_value: root[:content_id]
    }
  end
end

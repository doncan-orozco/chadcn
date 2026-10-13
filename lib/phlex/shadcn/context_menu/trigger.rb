# frozen_string_literal: true

# Radix ContextMenuTrigger: a span without classes, ids or aria. Hosts the shadcn--context-menu controller.
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::ContextMenu::Trigger < Phlex::Shadcn::Base
  include Phlex::Shadcn::ContextMenu::Support

  def initialize(disabled: false, as_child: false, **attrs)
    @disabled = disabled
    @as_child = as_child
    @attrs = attrs
    super()
  end

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

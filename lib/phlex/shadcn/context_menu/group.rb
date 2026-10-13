# frozen_string_literal: true

class Phlex::Shadcn::ContextMenu::Group < Phlex::Shadcn::Base
  include Phlex::Shadcn::ContextMenu::Support

  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    attrs = verbatim_class(merge_attrs({ role: "group", data: { slot: "context-menu-group" } }, @attrs), @attrs)
    render_part(:div, @as_child, attrs, &)
  end
end

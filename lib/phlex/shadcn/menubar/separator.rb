# frozen_string_literal: true

class Phlex::Shadcn::Menubar::Separator < Phlex::Shadcn::Base
  include Phlex::Shadcn::Menubar::Support

  CLASSES = "-mx-1 my-1 h-px bg-border"

  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    attrs = merge_attrs({ role: "separator", class: CLASSES, aria: { orientation: "horizontal" }, data: { slot: "menubar-separator" } },
                        @attrs)
    render_part(:div, @as_child, attrs, &)
  end
end

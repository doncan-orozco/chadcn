# frozen_string_literal: true

class Phlex::Shadcn::Menubar::Group < Phlex::Shadcn::Base
  include Phlex::Shadcn::Menubar::Support

  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    render_part(:div, @as_child, merge_attrs({ role: "group", data: { slot: "menubar-group" } }, @attrs), &)
  end
end

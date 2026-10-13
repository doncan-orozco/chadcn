# frozen_string_literal: true

class Phlex::Shadcn::Select::Group < Phlex::Shadcn::Base
  include Phlex::Shadcn::Select::Support

  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    previous = context[Phlex::Shadcn::Select::GROUP_KEY]
    id = context[Phlex::Shadcn::Select::GROUP_KEY] = next_id("group")
    attrs = merge_attrs({ role: "group", aria: { labelledby: id }, data: { slot: "select-group" } }, @attrs)
    render_part(:div, @as_child, attrs, &)
  ensure
    context[Phlex::Shadcn::Select::GROUP_KEY] = previous
  end
end

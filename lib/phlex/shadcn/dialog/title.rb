# frozen_string_literal: true

# shadcn DialogTitle. Marks the dialog as titled so Content can emit aria-labelledby.
class Phlex::Shadcn::Dialog::Title < Phlex::Shadcn::Base
  include Phlex::Shadcn::Dialog::Support

  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    root = root_context
    root[:title_present] = true
    attrs = merge_attrs({ id: root[:title_id], class: "text-lg leading-none font-semibold", data: { slot: "dialog-title" } }, @attrs)
    render_part(:h2, @as_child, attrs, &)
  end
end

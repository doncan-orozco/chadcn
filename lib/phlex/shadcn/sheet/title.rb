# frozen_string_literal: true

# shadcn SheetTitle. Marks the sheet as titled so Content can emit aria-labelledby.
class Phlex::Shadcn::Sheet::Title < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sheet::Support

  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    root = root_context
    root[:title_present] = true
    attrs = merge_attrs({ id: root[:title_id], class: "font-semibold text-foreground", data: { slot: "sheet-title" } }, @attrs)
    render_part(:h2, @as_child, attrs, &)
  end
end

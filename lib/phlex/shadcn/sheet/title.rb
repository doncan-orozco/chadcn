# frozen_string_literal: true

# shadcn SheetTitle. Marks the sheet as titled so Content can emit aria-labelledby.
#
# Accessible title (`h2`); makes Content emit `aria-labelledby`.
class Phlex::Shadcn::Sheet::Title < Phlex::Shadcn::Base
  include Phlex::Shadcn::Sheet::Support

  # @param as_child [Boolean, Symbol, Phlex::SGML] render onto the given child element (Radix Slot merge) instead of the default tag
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(as_child: false, **attrs)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yield the title content
  # @return [void]
  # @raise [ArgumentError] when rendered outside Sheet
  def view_template(&)
    root = root_context
    root[:title_present] = true
    attrs = merge_attrs({ id: root[:title_id], class: "font-semibold text-foreground", data: { slot: "sheet-title" } }, @attrs)
    render_part(:h2, @as_child, attrs, &)
  end
end

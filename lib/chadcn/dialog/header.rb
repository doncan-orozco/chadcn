# frozen_string_literal: true

# shadcn DialogHeader.
#
# Layout wrapper for the title and description (`div`).
class Chadcn::Dialog::Header < Chadcn::Base
  # @param attrs [Hash] HTML attributes merged into the element (class goes through tailwind-merge)
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  # @yield the part's content
  # @return [void]
  def view_template(&)
    div(**merge_attrs({ class: "flex flex-col gap-2 text-center sm:text-left", data: { slot: "dialog-header" } }, @attrs), &)
  end
end

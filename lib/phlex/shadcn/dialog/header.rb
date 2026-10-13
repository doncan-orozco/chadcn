# frozen_string_literal: true

# shadcn DialogHeader.
class Phlex::Shadcn::Dialog::Header < Phlex::Shadcn::Base
  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    div(**merge_attrs({ class: "flex flex-col gap-2 text-center sm:text-left", data: { slot: "dialog-header" } }, @attrs), &)
  end
end

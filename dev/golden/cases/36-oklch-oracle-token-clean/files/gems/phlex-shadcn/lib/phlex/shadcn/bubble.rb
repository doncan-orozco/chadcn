# frozen_string_literal: true

class Phlex::Shadcn::Bubble < Phlex::Shadcn::Base
  CLASS_NAME = "flex w-fit flex-col gap-1 bg-[oklch(from_var(--primary)_0.93_calc(c*0.4)_h)] text-foreground"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    div(**merge_attrs({ data: { slot: "bubble" }, class: CLASS_NAME }, @attrs), &)
  end
end

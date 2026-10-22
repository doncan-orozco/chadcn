# frozen_string_literal: true

class Chadcn::Bubble < Chadcn::Base
  CLASS_NAME = "flex w-fit flex-col gap-1 bg-[oklch(from_var(--primary)_0.93_calc(c*0.4)_h)] text-foreground"

  def initialize(**attrs)
    @attrs = attrs
    super()
  end

  def view_template(&)
    div(**merge_attrs({ data: { slot: "bubble" }, class: CLASS_NAME }, @attrs), &)
  end
end

class Chadcn::Bubble
  EXTRA = "text-[#fff] bg-[oklch(0.5 0 0)]"
end

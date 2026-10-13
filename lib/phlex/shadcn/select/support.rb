# frozen_string_literal: true

# What the parts share: the render context pushed by the root and the as_child switch.
module Phlex::Shadcn::Select::Support
  private

  def select_state
    context[Phlex::Shadcn::Select::ROOT_KEY] or raise ArgumentError, "#{self.class.name} must be used within Select"
  end

  # The first pass of the root only lets the Items register themselves.
  def collecting? = select_state[:phase] == :collect

  def blank_value? = select_state[:value].to_s.empty?

  def next_id(kind)
    state = select_state
    "#{state[:base]}-#{kind}-#{state[:counter] = state.fetch(:counter, 0) + 1}"
  end

  # What ItemIndicator renders inside a selected item. The Content ships it too so the controller can mark a new selection.
  def indicator
    span(aria: { hidden: "true" }) { render Phlex::Shadcn::Icon.new("check", class: "size-4") }
  end

  def render_part(tag_name, as_child, attrs, &)
    return render_as_child(as_child, **attrs, &) if as_child

    tag(tag_name, **attrs, &)
  end
end

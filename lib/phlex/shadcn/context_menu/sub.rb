# frozen_string_literal: true

# Radix MenuSub: renders no element. open: non-nil is controlled, like the root.
class Phlex::Shadcn::ContextMenu::Sub < Phlex::Shadcn::Base
  include Phlex::Shadcn::ContextMenu::Support

  def initialize(open: nil, default_open: false)
    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    super()
  end

  def view_template
    root = root_context
    previous = context[Phlex::Shadcn::ContextMenu::SUB_KEY]
    base = "#{root[:base]}-sub-#{Phlex::Shadcn::ContextMenu.next_sequence(context)}"
    context[Phlex::Shadcn::ContextMenu::SUB_KEY] = {
      trigger_id: "#{base}-trigger", content_id: "#{base}-content", open: @open, controlled: @controlled
    }
    yield if block_given?
  ensure
    context[Phlex::Shadcn::ContextMenu::SUB_KEY] = previous
  end
end

# frozen_string_literal: true

# Radix MenuSub: renders no element. open: non-nil is controlled, like the root.
class Phlex::Shadcn::Menubar::Sub < Phlex::Shadcn::Base
  include Phlex::Shadcn::Menubar::Support

  def initialize(open: nil, default_open: false)
    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    super()
  end

  def view_template
    root = root_context
    previous = context[Phlex::Shadcn::Menubar::SUB_KEY]
    base = "#{root[:base]}-sub-#{Phlex::Shadcn::Menubar.next_sequence(context)}"
    context[Phlex::Shadcn::Menubar::SUB_KEY] = {
      trigger_id: "#{base}-trigger", content_id: "#{base}-content", open: @open, controlled: @controlled
    }
    yield if block_given?
  ensure
    context[Phlex::Shadcn::Menubar::SUB_KEY] = previous
  end
end

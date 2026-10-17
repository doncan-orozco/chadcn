# frozen_string_literal: true

# Radix MenuSub: renders no element, it groups a {SubTrigger} with its {SubContent}. +open:+ non-nil is controlled, like the
# root: the controller dispatches +open-change+ (+detail.open+) and the server decides. Must be rendered inside a
# {Phlex::Shadcn::Menubar} (raises +ArgumentError+ at render otherwise).
#
# @example
#   bar.sub { bar.sub_trigger { "Share" }; bar.sub_content { bar.item { "Email" } } }
class Phlex::Shadcn::Menubar::Sub < Phlex::Shadcn::Base
  include Phlex::Shadcn::Menubar::Support

  # @param open [Boolean, nil] non-nil is controlled: renders open/closed and the user cannot change it. Default +nil+
  # @param default_open [Boolean] only affects the server markup (rendered +aria-expanded="true"+, +data-state="open"+): the controller
  #   closes every sub on mount and dispatches +open-change+ (+open: false+), so it never stays open. A controlled +open: true+ stays open
  #   (it also dispatches +open-change+ with +open: false+ at mount). Default +false+
  # @raise [ArgumentError] at render, when not inside a {Phlex::Shadcn::Menubar}
  def initialize(open: nil, default_open: false)
    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    super()
  end

  # @yield the SubTrigger and SubContent
  # @return [void]
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

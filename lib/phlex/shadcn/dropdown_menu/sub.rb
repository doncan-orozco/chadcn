# frozen_string_literal: true

# Radix MenuSub: renders no element. It wires a SubTrigger to its SubContent (ids, open state) for the parts inside.
# +open:+ non-nil is controlled, like the root. Its +open-change+ event is dispatched with the SubTrigger as target.
#
# @example
#   menu.sub do
#     menu.sub_trigger { "More" }
#     menu.sub_content { menu.item { "Export" } }
#   end
class Phlex::Shadcn::DropdownMenu::Sub < Phlex::Shadcn::Base
  include Phlex::Shadcn::DropdownMenu::Support

  # @param open [Boolean, nil] non-nil makes the sub menu controlled (user actions only dispatch +open-change+), default +nil+
  # @param default_open [Boolean] default +false+; only affects the server markup: the controller closes every sub when
  #   its menu mounts (reporting +open-change+), so only a controlled +open: true+ keeps a sub open
  def initialize(open: nil, default_open: false)
    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    super()
  end

  # @yield the SubTrigger and SubContent
  # @raise [ArgumentError] when rendered outside a DropdownMenu
  # @return [void]
  def view_template
    root = root_context
    previous = context[Phlex::Shadcn::DropdownMenu::SUB_KEY]
    base = "#{root[:base]}-sub-#{Phlex::Shadcn::DropdownMenu.next_sequence(context)}"
    context[Phlex::Shadcn::DropdownMenu::SUB_KEY] = {
      trigger_id: "#{base}-trigger", content_id: "#{base}-content", open: @open, controlled: @controlled
    }
    yield if block_given?
  ensure
    context[Phlex::Shadcn::DropdownMenu::SUB_KEY] = previous
  end
end

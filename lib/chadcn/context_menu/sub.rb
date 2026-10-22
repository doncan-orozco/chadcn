# frozen_string_literal: true

# Radix MenuSub: renders no element. It generates the ids that tie its {SubTrigger} to its {SubContent} and holds the sub menu
# state. +open:+ non-nil is controlled, like the root.
#
# @example
#   menu.sub do
#     menu.sub_trigger { "More tools" }
#     menu.sub_content { menu.item { "Save page as..." } }
#   end
class Chadcn::ContextMenu::Sub < Chadcn::Base
  include Chadcn::ContextMenu::Support

  # @param open [Boolean, nil] non-nil makes the sub menu controlled and rendered open or closed accordingly (default +nil+)
  # @param default_open [Boolean] default +false+; only affects the server markup: the controller closes every sub when
  #   its menu mounts (reporting +open-change+), so only a controlled +open: true+ keeps a sub open
  def initialize(open: nil, default_open: false)
    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    super()
  end

  # @yield the SubTrigger and SubContent
  # @return [void]
  # @raise [ArgumentError] when not rendered within a {Chadcn::ContextMenu}
  def view_template
    root = root_context
    previous = context[Chadcn::ContextMenu::SUB_KEY]
    base = "#{root[:base]}-sub-#{Chadcn::ContextMenu.next_sequence(context)}"
    context[Chadcn::ContextMenu::SUB_KEY] = {
      trigger_id: "#{base}-trigger", content_id: "#{base}-content", open: @open, controlled: @controlled
    }
    yield if block_given?
  ensure
    context[Chadcn::ContextMenu::SUB_KEY] = previous
  end
end

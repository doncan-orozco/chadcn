# frozen_string_literal: true

# shadcn Resizable over react-resizable-panels (`Group`, `Panel`, `Separator`). Spec: dev/port/specs/resizable.md.
# Behavior: controllers/chadcn/resizable_controller.js (one controller per group element).
#
# Namespace root: it renders no element. The three exports are {PanelGroup}, {Panel} and {Handle}; nest panels and handles
# directly inside the group (a nested group goes inside a panel).
#
# @example
#   render Chadcn::Resizable::PanelGroup.new(class: "h-[200px] w-[401px]") do
#     render(Chadcn::Resizable::Panel.new) { "One" }
#     render Chadcn::Resizable::Handle.new(with_handle: true)
#     render(Chadcn::Resizable::Panel.new) { "Two" }
#   end
class Chadcn::Resizable < Chadcn::Base
  # Render-context key of the enclosing group (orientation, default layout, cursor flag) read by panels and handles.
  #
  # @api private
  GROUP_KEY = :shadcn_resizable_group
  # Render-context counter behind the React-style ids (`_r_0_`).
  #
  # @api private
  SEQUENCE_KEY = :shadcn_resizable_sequence

  # @yieldparam resizable [Chadcn::Resizable] the root
  # @return [void]
  def view_template
    yield self if block_given?
  end
end

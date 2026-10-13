# frozen_string_literal: true

# shadcn ContextMenu (Radix ContextMenu over the Menu code shared with DropdownMenu). Spec: docs/shadcn-port/specs/context-menu.md.
# Behavior lives in controllers/shadcn/context_menu_controller.js (hosted by the Trigger).
#
# Root, Sub and Portal render no element: they push their state into the Phlex render context for the parts inside.
# Content/SubContent ship their markup in an inert <template> that the controller clones while the menu is open.
class Phlex::Shadcn::ContextMenu < Phlex::Shadcn::Base
  include Phlex::Shadcn::Direction::Consumer

  ROOT_KEY = :shadcn_context_menu_root
  SUB_KEY = :shadcn_context_menu_sub
  PORTAL_KEY = :shadcn_context_menu_portal
  RADIO_GROUP_KEY = :shadcn_context_menu_radio_group
  SEQUENCE_KEY = :shadcn_context_menu_sequence
  DIRECTIONS = %w[ltr rtl].freeze

  # open: non-nil is controlled. Radix has no default open for the root.
  def initialize(open: nil, dir: nil, modal: true)
    @controlled = !open.nil?
    @open = @controlled ? open : false
    @modal = modal
    @dir = dir.to_s if DIRECTIONS.include?(dir.to_s)
    super()
  end

  def view_template
    previous = context[ROOT_KEY]
    base = "context-menu-#{self.class.next_sequence(context)}"
    context[ROOT_KEY] = {
      content_id: "#{base}-content", base:, open: @open, controlled: @controlled, modal: @modal, dir: use_direction(@dir)
    }
    yield self if block_given?
  ensure
    context[ROOT_KEY] = previous
  end

  # Per render counter (no SecureRandom): ids are only compared through their relations.
  def self.next_sequence(context) = context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1
end

# frozen_string_literal: true

# shadcn DropdownMenu (Radix DropdownMenu + Menu). Spec: docs/shadcn-port/specs/dropdown-menu.md.
# Behavior lives in controllers/v2/dropdown_menu_controller.js (hosted by the Trigger).
#
# Root, Sub and Portal render no element: they push their state into the Phlex render context for the parts inside.
# Radix mounts Content/SubContent only while open, so those parts ship their markup in an inert <template> that the
# controller clones through the template_mount primitive.
class Phlex::Shadcn::DropdownMenu < Phlex::Shadcn::Base
  include Phlex::Shadcn::Direction::Consumer

  ROOT_KEY = :v2_dropdown_menu_root
  SUB_KEY = :v2_dropdown_menu_sub
  PORTAL_KEY = :v2_dropdown_menu_portal
  RADIO_GROUP_KEY = :v2_dropdown_menu_radio_group
  SEQUENCE_KEY = :v2_dropdown_menu_sequence
  DIRECTIONS = %w[ltr rtl].freeze

  # open: non-nil is controlled (the server decides the state, user actions only dispatch open-change).
  def initialize(open: nil, default_open: false, modal: true, dir: nil)
    @controlled = !open.nil?
    @open = @controlled ? open : default_open
    @modal = modal
    @dir = dir.to_s if DIRECTIONS.include?(dir.to_s)
    super()
  end

  def view_template
    previous = context[ROOT_KEY]
    base = "dropdown-menu-#{self.class.next_sequence(context)}"
    context[ROOT_KEY] = {
      trigger_id: "#{base}-trigger", content_id: "#{base}-content", base:,
      open: @open, controlled: @controlled, modal: @modal, dir: use_direction(@dir)
    }
    yield self if block_given?
  ensure
    context[ROOT_KEY] = previous
  end

  # Per render counter (no SecureRandom): ids are only compared through their relations.
  def self.next_sequence(context) = context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1
end

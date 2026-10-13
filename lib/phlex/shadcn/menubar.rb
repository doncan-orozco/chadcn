# frozen_string_literal: true

# shadcn Menubar over Radix Menubar + Menu. Spec: docs/shadcn-port/specs/menubar.md.
# Behavior lives in controllers/v2/menubar_controller.js (hosted by the root, one controller for every menu and sub).
#
# Menu, Sub and Portal render no element: they push their state into the Phlex render context for the parts inside.
# Radix mounts Content/SubContent only while open, so those parts ship their markup in an inert <template> that the
# controller clones through the template_mount primitive.
class Phlex::Shadcn::Menubar < Phlex::Shadcn::Base
  include Phlex::Shadcn::Direction::Consumer

  ROOT_KEY = :v2_menubar_root
  MENU_KEY = :v2_menubar_menu
  SUB_KEY = :v2_menubar_sub
  PORTAL_KEY = :v2_menubar_portal
  RADIO_GROUP_KEY = :v2_menubar_radio_group
  SEQUENCE_KEY = :v2_menubar_sequence
  DIRECTIONS = %w[ltr rtl].freeze
  CLASSES = "flex h-9 items-center gap-1 rounded-md border bg-background p-1 shadow-xs"

  # value: non-nil is controlled (the server decides the open menu, user actions only dispatch value-change).
  def initialize(value: nil, default_value: nil, loop: true, dir: nil, as_child: false, **attrs)
    @controlled = !value.nil?
    @value = (@controlled ? value : default_value).to_s
    @loop = loop
    @dir = dir.to_s if DIRECTIONS.include?(dir.to_s)
    @as_child = as_child
    @attrs = attrs
    super()
  end

  def view_template(&)
    previous = context[ROOT_KEY]
    root = { base: "menubar-#{self.class.next_sequence(context)}", value: @value, dir: use_direction(@dir) }
    context[ROOT_KEY] = root
    attrs = merge_attrs({
                          role: "menubar", class: CLASSES, tabindex: "0", style: "outline: none",
                          data: {
                            slot: "menubar", orientation: "horizontal", controller: "v2--menubar",
                            v2__menubar_value_value: @value, v2__menubar_controlled_value: @controlled.to_s,
                            v2__menubar_loop_value: @loop.to_s, v2__menubar_dir_value: root[:dir]
                          }
                        }, @attrs)
    if @as_child
      render_as_child(@as_child, **attrs) { yield self if block_given? }
    else
      div(**attrs) { yield self if block_given? }
    end
  ensure
    context[ROOT_KEY] = previous
  end

  # Per render counter (no SecureRandom): ids are only compared through their relations.
  def self.next_sequence(context) = context[SEQUENCE_KEY] = context.fetch(SEQUENCE_KEY, 0) + 1
end

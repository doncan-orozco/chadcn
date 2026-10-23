# frozen_string_literal: true

# shadcn ContextMenu (Radix ContextMenu over the Menu code shared with DropdownMenu). Spec: port spec (dev kit).
# Behavior lives in controllers/chadcn/context_menu_controller.js (hosted by the {Trigger}).
#
# The root renders no element: it pushes its state into the Phlex render context for the parts inside. Only {Trigger},
# {Content}, {Sub} and {SubContent} read that state and raise +ArgumentError+ at render time outside a ContextMenu ({SubTrigger}
# raises only when there is no surrounding {Sub}); the other parts ({Item}, {CheckboxItem}, {RadioItem}, {RadioGroup},
# {Group}, {Label}, {Separator}, {Shortcut} and {Portal}) render without a root. {Content} and {SubContent} ship their
# markup in an inert +<template>+ that the controller clones while the menu is open. A right click (or a long press with touch
# or pen) on the {Trigger} opens the menu at the pointer.
#
# Events and focus: every event is named +chadcn--context-menu:<name>+. The root dispatches +open-change+ (+detail.open+; the
# only state change a controlled menu performs). Selecting an item dispatches the cancelable +select+ on the item (preventing it
# keeps the menu open), then +checked-change+ (+detail.checked+) for a {CheckboxItem} or +value-change+ (+detail.value+) for a
# {RadioItem}; those two are not cancelable and fire even when +select+ was prevented. The content forwards the cancelable
# +escape-key-down+, +pointer-down-outside+, +focus-outside+ and +interact-outside+ (each with +detail.originalEvent+; preventing
# one keeps the menu from dismissing) and the cancelable +open-auto-focus+; +close-auto-focus+ is cancelable and is dispatched
# on the {Trigger}. A {Sub} dispatches its own +open-change+ (+detail.open+) on its {SubTrigger}. When the menu closes, focus
# returns to the element that had it when the menu mounted, unless +close-auto-focus+ was prevented, the page is disconnecting,
# that element is no longer connected or already has focus, or the close followed an outside interaction that suppresses the
# return: any outside interaction when the root is non-modal, or (on a modal root, the default) a right click or ctrl+click
# outside; a plain outside click on a modal menu still returns focus.
#
# The parts are available as helpers on the yielded root (and on any subclass of it); see the +@!method+ entries below.
#
# @example
#   render Chadcn::ContextMenu.new do |menu|
#     menu.trigger { "Right click here" }
#     menu.content(class: "w-52") do
#       menu.item { "Back" }
#       menu.checkbox_item(checked: true) { "Show bookmarks" }
#       menu.separator
#       menu.sub do
#         menu.sub_trigger { "More" }
#         menu.sub_content { menu.item { "Save as..." } }
#       end
#     end
#   end
#
# @!method trigger(**attrs, &block)
#   Sugar for +render Chadcn::ContextMenu::Trigger.new(**attrs), &block+.
#   @param attrs [Hash] keyword arguments of {Chadcn::ContextMenu::Trigger#initialize}
#   @return [void]
#
# @!method content(**attrs, &block)
#   Sugar for +render Chadcn::ContextMenu::Content.new(**attrs), &block+.
#   @param attrs [Hash] keyword arguments of {Chadcn::ContextMenu::Content#initialize}
#   @return [void]
#
# @!method item(**attrs, &block)
#   Sugar for +render Chadcn::ContextMenu::Item.new(**attrs), &block+.
#   @param attrs [Hash] keyword arguments of {Chadcn::ContextMenu::Item#initialize}
#   @return [void]
#
# @!method checkbox_item(**attrs, &block)
#   Sugar for +render Chadcn::ContextMenu::CheckboxItem.new(**attrs), &block+.
#   @param attrs [Hash] keyword arguments of {Chadcn::ContextMenu::CheckboxItem#initialize}
#   @return [void]
#
# @!method radio_item(**attrs, &block)
#   Sugar for +render Chadcn::ContextMenu::RadioItem.new(**attrs), &block+.
#   @param attrs [Hash] keyword arguments of {Chadcn::ContextMenu::RadioItem#initialize}
#   @return [void]
#
# @!method label(**attrs, &block)
#   Sugar for +render Chadcn::ContextMenu::Label.new(**attrs), &block+.
#   @param attrs [Hash] keyword arguments of {Chadcn::ContextMenu::Label#initialize}
#   @return [void]
#
# @!method separator(**attrs, &block)
#   Sugar for +render Chadcn::ContextMenu::Separator.new(**attrs), &block+.
#   @param attrs [Hash] keyword arguments of {Chadcn::ContextMenu::Separator#initialize}
#   @return [void]
#
# @!method shortcut(**attrs, &block)
#   Sugar for +render Chadcn::ContextMenu::Shortcut.new(**attrs), &block+.
#   @param attrs [Hash] keyword arguments of {Chadcn::ContextMenu::Shortcut#initialize}
#   @return [void]
#
# @!method group(**attrs, &block)
#   Sugar for +render Chadcn::ContextMenu::Group.new(**attrs), &block+.
#   @param attrs [Hash] keyword arguments of {Chadcn::ContextMenu::Group#initialize}
#   @return [void]
#
# @!method portal(**attrs, &block)
#   Sugar for +render Chadcn::ContextMenu::Portal.new(**attrs), &block+.
#   @param attrs [Hash] keyword arguments of {Chadcn::ContextMenu::Portal#initialize}
#   @return [void]
#
# @!method sub(**attrs, &block)
#   Sugar for +render Chadcn::ContextMenu::Sub.new(**attrs), &block+.
#   @param attrs [Hash] keyword arguments of {Chadcn::ContextMenu::Sub#initialize}
#   @return [void]
#
# @!method sub_content(**attrs, &block)
#   Sugar for +render Chadcn::ContextMenu::SubContent.new(**attrs), &block+.
#   @param attrs [Hash] keyword arguments of {Chadcn::ContextMenu::SubContent#initialize}
#   @return [void]
#
# @!method sub_trigger(**attrs, &block)
#   Sugar for +render Chadcn::ContextMenu::SubTrigger.new(**attrs), &block+.
#   @param attrs [Hash] keyword arguments of {Chadcn::ContextMenu::SubTrigger#initialize}
#   @return [void]
#
# @!method radio_group(**attrs, &block)
#   Sugar for +render Chadcn::ContextMenu::RadioGroup.new(**attrs), &block+.
#   @param attrs [Hash] keyword arguments of {Chadcn::ContextMenu::RadioGroup#initialize}
#   @return [void]
class Chadcn::ContextMenu < Chadcn::Base
  include Chadcn::Direction::Consumer

  # @api private
  # @return [Symbol] render-context key holding the root state
  ROOT_KEY = :shadcn_context_menu_root
  # @api private
  # @return [Symbol] render-context key holding the current Sub state
  SUB_KEY = :shadcn_context_menu_sub
  # @api private
  # @return [Symbol] render-context key holding the current Portal state
  PORTAL_KEY = :shadcn_context_menu_portal
  # @api private
  # @return [Symbol] render-context key holding the current RadioGroup value
  RADIO_GROUP_KEY = :shadcn_context_menu_radio_group
  # @api private
  # @return [Symbol] render-context key holding the id counter (per request with the engine, per render without it, see Chadcn::Sequence)
  SEQUENCE_KEY = :shadcn_context_menu_sequence
  # @api private
  # @return [Array<String>] the values accepted for +dir:+
  DIRECTIONS = %w[ltr rtl].freeze

  # @param open [Boolean, nil] +nil+ (default) leaves the menu uncontrolled and closed on first render. Any non-nil value makes it
  #   controlled: it is rendered open or closed and the controller only dispatches +chadcn--context-menu:open-change+; it never
  #   flips the state itself. Radix has no default open for the root (there is no +default_open:+; passing it raises
  #   +ArgumentError+ at construction)
  # @param dir [String, Symbol, nil] +"ltr"+ or +"rtl"+ sets the direction of the menu; any other value (including +nil+) is
  #   ignored and the direction comes from the surrounding {Chadcn::Direction} provider, or +"ltr"+
  # @param modal [Boolean] default +true+; passed to the controller as its +modal+ value (not validated)
  # @param id [String, nil] id of the content (what the trigger controls); the other generated ids derive from it (`"x-trigger"`,
  #   `"x-sub-1-content"`). The content carries it as its +id+ only when given (Radix renders none).
  #   Default `context-menu-N`, numbered per request with the engine, per render without it
  def initialize(open: nil, dir: nil, modal: true, id: nil)
    @controlled = !open.nil?
    @open = @controlled ? open : false
    @modal = modal
    @dir = dir.to_s if DIRECTIONS.include?(dir.to_s)
    @id = id
    super()
  end

  # @yield [root] the block renders the parts of the menu
  # @yieldparam root [Chadcn::ContextMenu] self, which carries the part helpers (+root.item { }+)
  # @return [void]
  def view_template
    previous = context[ROOT_KEY]
    base = @id || "context-menu-#{next_sequence(SEQUENCE_KEY)}"
    context[ROOT_KEY] = {
      content_id: base, id: @id, base:, subs: 0, open: @open, controlled: @controlled, modal: @modal, dir: use_direction(@dir)
    }
    yield self if block_given?
  ensure
    context[ROOT_KEY] = previous
  end
end

# frozen_string_literal: true

using Chadcn::Values::Refinements

# shadcn Tabs over Radix Tabs. Spec: docs/shadcn-port/specs/tabs.md.
# Behavior: controllers/chadcn/tabs_controller.js.
#
# Root of the tabs. Yields itself, so `list`, `trigger` and `content` are yielded-root helpers equal to rendering
# `Tabs::List`, `Tabs::Trigger` and `Tabs::Content`.
#
# @example
#   render Chadcn::Tabs.new(default_value: "account") do |tabs|
#     tabs.list do
#       tabs.trigger(value: "account") { "Account" }
#       tabs.trigger(value: "password") { "Password" }
#     end
#     tabs.content(value: "account") { "Account settings" }
#     tabs.content(value: "password") { "Password settings" }
#   end
class Chadcn::Tabs < Chadcn::Base
  include Chadcn::Direction::Consumer

  # @api private
  ROOT_KEY = :shadcn_tabs_root
  # Default Tailwind classes of the root element.
  #
  # @api private
  CLASSES = "group/tabs flex gap-2 data-[orientation=horizontal]:flex-col"
  # Base Tailwind classes shared by every tabs list variant.
  #
  # @api private
  LIST_BASE = "group/tabs-list inline-flex w-fit items-center justify-center rounded-lg p-[3px] text-muted-foreground group-data-[orientation=horizontal]/tabs:h-9 group-data-[orientation=vertical]/tabs:h-fit group-data-[orientation=vertical]/tabs:flex-col data-[variant=line]:rounded-none"
  # Variant-specific list classes, keyed by variant name.
  #
  # @api private
  LIST_VARIANTS = { "default" => "bg-muted", "line" => "gap-1 bg-transparent" }.freeze

  # tabsListVariants (cva).
  #
  # @param variant [String, Symbol] `"default"` or `"line"` (unknown values fall back to `"default"`)
  # @return [String] the list classes for the variant
  def self.list_variants(variant: "default")
    [ LIST_BASE, LIST_VARIANTS.fetch(variant.to_s) { LIST_VARIANTS["default"] } ].join(" ")
  end

  # value: non-nil is controlled (user actions only dispatch value-change, the caller re-renders with the new value).
  #
  # @param value [String, Symbol, nil] active tab value; non-nil makes the tabs controlled
  # @param default_value [String, Symbol, nil] initially active tab when uncontrolled
  # @param orientation [String, Symbol] `"horizontal"` or `"vertical"`
  # @param dir [String, Symbol, nil] reading direction (`"ltr"`/`"rtl"`); falls back to the Direction provider
  # @param activation_mode [String, Symbol] `"automatic"` or `"manual"` (anything else is `"automatic"`)
  # @param as_child [false, nil, Symbol, String, Chadcn::Base] a tag name (`:a`) or a component to render instead of the default element (Radix Slot);
  #   the part's attributes are merged onto it. `true` is not supported.
  # @param attrs [Hash] HTML attributes merged onto the root element (`id:` is the base of the trigger/panel ids)
  def initialize(value: nil, default_value: nil, orientation: "horizontal", dir: nil, activation_mode: "automatic",
                 as_child: false, **attrs)
    @controlled = !value.nil?
    @value = (@controlled ? value : default_value).to_s
    @orientation = orientation.to_s
    @dir = dir&.to_s
    @activation_mode = activation_mode.to_s == "manual" ? "manual" : "automatic"
    @as_child = as_child
    @attrs = attrs
    super()
  end

  # @yieldparam tabs [Chadcn::Tabs] the root, exposing the part helpers
  # @return [void]
  def view_template
    previous = context[ROOT_KEY]
    dir = use_direction(@dir)
    context[ROOT_KEY] = { base_id: base_id, value: @value, orientation: @orientation, dir:, activation_mode: @activation_mode }
    attrs = merge_attrs({ dir:, class: CLASSES, data: root_data }, @attrs)
    content = proc { yield self if block_given? }
    @as_child ? render_as_child(@as_child, **attrs, &content) : div(**attrs, &content)
  ensure
    context[ROOT_KEY] = previous
  end

  private

  def base_id
    @attrs[:id].unless_blank || "radix-tabs-#{SecureRandom.alphanumeric(6).downcase}"
  end

  def root_data
    {
      slot: "tabs",
      orientation: @orientation,
      controller: "chadcn--tabs",
      chadcn__tabs_value_value: @value,
      chadcn__tabs_controlled_value: @controlled.to_s,
      chadcn__tabs_activation_mode_value: @activation_mode,
      chadcn__tabs_orientation_value: @orientation,
      chadcn__tabs_dir_value: context[ROOT_KEY][:dir]
    }
  end
end

# frozen_string_literal: true

# shadcn Tabs over Radix Tabs. Spec: docs/shadcn-port/specs/tabs.md.
# Behavior: controllers/shadcn/tabs_controller.js.
using Phlex::Shadcn::Values::Refinements

class Phlex::Shadcn::Tabs < Phlex::Shadcn::Base
  include Phlex::Shadcn::Direction::Consumer

  ROOT_KEY = :shadcn_tabs_root
  CLASSES = "group/tabs flex gap-2 data-[orientation=horizontal]:flex-col"
  LIST_BASE = "group/tabs-list inline-flex w-fit items-center justify-center rounded-lg p-[3px] text-muted-foreground group-data-[orientation=horizontal]/tabs:h-9 group-data-[orientation=vertical]/tabs:h-fit group-data-[orientation=vertical]/tabs:flex-col data-[variant=line]:rounded-none"
  LIST_VARIANTS = { "default" => "bg-muted", "line" => "gap-1 bg-transparent" }.freeze

  # tabsListVariants (cva).
  def self.list_variants(variant: "default")
    [ LIST_BASE, LIST_VARIANTS.fetch(variant.to_s) { LIST_VARIANTS["default"] } ].join(" ")
  end

  # value: non-nil is controlled (user actions only dispatch value-change, the caller re-renders with the new value).
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
      controller: "shadcn--tabs",
      shadcn__tabs_value_value: @value,
      shadcn__tabs_controlled_value: @controlled.to_s,
      shadcn__tabs_activation_mode_value: @activation_mode,
      shadcn__tabs_orientation_value: @orientation,
      shadcn__tabs_dir_value: context[ROOT_KEY][:dir]
    }
  end
end

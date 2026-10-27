# frozen_string_literal: true

# shadcn ResizablePanelGroup over react-resizable-panels `Group`: the flex container and Stimulus host.
#
# Events dispatched from the element (`bubbles`, detail in brackets): `chadcn--resizable:layout-change` [layout],
# `chadcn--resizable:layout-changed` [layout, isUserInteraction, requestedLayout].
#
# @example
#   render Chadcn::Resizable::PanelGroup.new(orientation: :vertical, class: "h-[401px] w-[200px]") do
#     render(Chadcn::Resizable::Panel.new) { "One" }
#     render Chadcn::Resizable::Handle.new
#     render(Chadcn::Resizable::Panel.new) { "Two" }
#   end
class Chadcn::Resizable::PanelGroup < Chadcn::Base
  include Chadcn::Resizable::Support

  # Classes of the group, verbatim from the oracle.
  #
  # @api private
  CLASSES = "flex h-full w-full aria-[orientation=vertical]:flex-col"
  # Allowed values of `resize_preview_mode:`.
  # @return [Array<String>]
  PREVIEW_MODES = %w[panel separator].freeze
  # Default `resize_target_minimum_size:` in pixels.
  # @return [Hash{Symbol => Integer}]
  TARGET_SIZE = { coarse: 20, fine: 10 }.freeze

  # @param orientation [String, Symbol] one of {Chadcn::Resizable::Support::ORIENTATIONS} (default "horizontal")
  # @param default_layout [Hash{String, Symbol => Numeric}, nil] percent per panel id, applied when it names exactly the panels
  # @param disabled [Boolean] disables keyboard and pointer resizing of the whole group
  # @param disable_cursor [Boolean] keeps the document cursor unchanged while hovering or dragging handles
  # @param resize_preview_mode [String, Symbol] one of {PREVIEW_MODES} (default "panel")
  # @param resize_target_minimum_size [Hash{Symbol => Numeric}] minimum hit size in pixels (`coarse:` and `fine:` pointers)
  # @param id [String, Integer, nil] element id and layout key; a React-style id is generated without it
  # @param style [String, Hash, nil] merged where the library merges it
  # @param attrs [Hash] HTML attributes for the group div (`class:` merged last, `aria:`, `data:`)
  # @raise [ArgumentError] when `orientation:` or `resize_preview_mode:` is not an allowed value
  def initialize(orientation: "horizontal", default_layout: nil, disabled: false, disable_cursor: false,
                 resize_preview_mode: "panel", resize_target_minimum_size: TARGET_SIZE, id: nil, style: nil, **attrs)
    @orientation = choice(orientation, ORIENTATIONS, "orientation")
    @default_layout = default_layout&.transform_keys(&:to_s)
    @disabled = disabled
    @disable_cursor = disable_cursor
    @preview_mode = choice(resize_preview_mode, PREVIEW_MODES, "resize_preview_mode")
    @target_size = TARGET_SIZE.merge(resize_target_minimum_size.transform_keys(&:to_sym))
    @id = id
    @style = style
    @attrs = attrs
    super()
  end

  # @yieldparam group [Chadcn::Resizable::PanelGroup] the group, exposing the part helpers
  # @return [void]
  def view_template
    previous = context[Chadcn::Resizable::GROUP_KEY]
    id = resizable_id(@id)
    context[Chadcn::Resizable::GROUP_KEY] = { orientation: @orientation, default_layout: @default_layout, disable_cursor: @disable_cursor }
    div(**group_attrs(id)) { yield self if block_given? }
  ensure
    context[Chadcn::Resizable::GROUP_KEY] = previous
  end

  private

  def group_attrs(id)
    merge_attrs({
      class: CLASSES,
      data: { slot: "resizable-panel-group", group: "true", testid: id, controller: "chadcn--resizable" }.merge(wiring),
      id:,
      style: group_style
    }, without_forced(@attrs, data: %i[group testid], keys: %i[id style]))
  end

  def group_style
    horizontal = @orientation == "horizontal"
    style_attr({ "height" => "100%", "width" => "100%", "overflow" => "hidden",
                 "position" => (@preview_mode == "separator" ? "relative" : nil) }, @style,
               { "display" => "flex", "flex-direction" => (horizontal ? "row" : "column"), "flex-wrap" => "nowrap",
                 "touch-action" => (horizontal ? "pan-y" : "pan-x") })
  end

  def wiring
    {
      chadcn__resizable_orientation_value: @orientation,
      chadcn__resizable_disabled_value: @disabled.to_s,
      chadcn__resizable_disable_cursor_value: @disable_cursor.to_s,
      chadcn__resizable_default_layout_value: (json(@default_layout) if @default_layout),
      chadcn__resizable_resize_preview_mode_value: @preview_mode,
      chadcn__resizable_resize_target_minimum_size_value: json(@target_size)
    }
  end
end

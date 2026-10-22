# frozen_string_literal: true

using Chadcn::Values::Refinements

# The popup: a +div role="listbox"+ inside an inert +template+ (with the viewport, the scroll buttons and a +data-options+ JSON
# for the controller; the controller clones it into +body+ when opening and creates the positioning wrapper). Radix mounts it only
# while open, hence the inert template. Renders only the block during the root's collect pass. +as_child:+ is not supported (Radix SelectContent has none).
# The +side+, +align+ and collision options are
# only applied by the controller in the +"popper"+ position.
#
# @example
#   select.content(position: "popper", side: "top") do
#     select.item(value: "apple") { "Apple" }
#   end
class Chadcn::Select::Content < Chadcn::Base
  include Chadcn::Select::Support

  # @return [String] Tailwind classes of the listbox
  CLASSES = "relative z-50 max-h-(--radix-select-content-available-height) min-w-[8rem] origin-(--radix-select-content-transform-origin) overflow-x-hidden overflow-y-auto rounded-md border bg-popover text-popover-foreground shadow-md data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"
  # @return [String] extra classes of the listbox in the popper position
  POPPER_CLASSES = "data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1"
  # @return [String] Tailwind classes of the viewport
  VIEWPORT_CLASSES = "p-1"
  # @return [String] extra viewport classes in the popper position
  VIEWPORT_POPPER_CLASSES = "h-[var(--radix-select-trigger-height)] w-full min-w-[var(--radix-select-trigger-width)] scroll-my-1"
  # @return [String] inline style of the viewport
  VIEWPORT_STYLE = "position: relative; flex: 1 1 0%; overflow: hidden auto;"
  # @api private
  # @return [String] CSS that hides the viewport scrollbar (rendered in a +style+ tag)
  VIEWPORT_CSS = "[data-radix-select-viewport]{scrollbar-width:none;-ms-overflow-style:none;-webkit-overflow-scrolling:touch;}[data-radix-select-viewport]::-webkit-scrollbar{display:none}"
  # @return [Hash{String=>String}] CSS variables mapping the Radix select tokens to the popper ones (popper position only)
  POPPER_STYLE_VARS = {
    "--radix-select-content-transform-origin" => "var(--radix-popper-transform-origin)",
    "--radix-select-content-available-width" => "var(--radix-popper-available-width)",
    "--radix-select-content-available-height" => "var(--radix-popper-available-height)",
    "--radix-select-trigger-width" => "var(--radix-popper-anchor-width)",
    "--radix-select-trigger-height" => "var(--radix-popper-anchor-height)"
  }.freeze
  # @return [Array<String>] accepted +position:+ values
  POSITIONS = %w[item-aligned popper].freeze

  # The popper options only apply to the popper position; the Radix popper default start alignment is overridden by the shadcn
  # center.
  #
  # @param position [String, Symbol] +"item-aligned"+ or +"popper"+ (underscores become hyphens)
  # @param align [String, Symbol] +"start"+, +"center"+ or +"end"+ (popper only; not validated)
  # @param side [String, Symbol] +"top"+, +"right"+, +"bottom"+ or +"left"+ (popper only; not validated)
  # @param side_offset [Integer] distance in px from the trigger (popper only)
  # @param align_offset [Integer] offset in px along the alignment axis (popper only)
  # @param avoid_collisions [Boolean] flip/shift to stay in the viewport (popper only)
  # @param collision_padding [Integer, Hash] padding in px kept from the boundary edges (popper only)
  # @param collision_boundary [String, Array<String>, nil] CSS selector(s) of the collision boundary elements; +nil+ uses the viewport
  # @param sticky [String, Symbol] +"partial"+ or +"always"+ (popper only; not validated)
  # @param hide_when_detached [Boolean] hide when the trigger is fully clipped (popper only)
  # @param arrow_padding [Integer] padding in px between the arrow and the edges (popper only)
  # @param force_mount [Boolean] keep the content mounted while closed
  # @param attrs [Hash] HTML attributes merged into the element (+class+ is merged with Tailwind conflict resolution, +data+/+aria+ deep-merged, caller wins)
  # @raise [ArgumentError] at construction when +position+ is not one of {POSITIONS}
  def initialize(position: "item-aligned", align: "center", side: "bottom", side_offset: 0, align_offset: 0, avoid_collisions: true,
                 collision_padding: 10, collision_boundary: nil, sticky: "partial", hide_when_detached: false, arrow_padding: 0,
                 force_mount: false, **attrs)
    @position = normalize_option(position)
    raise ArgumentError, "position must be one of #{POSITIONS.join(', ')}" unless POSITIONS.include?(@position)

    @options = {
      position: @position, side: side.to_s, sideOffset: side_offset, align: align.to_s, alignOffset: align_offset,
      avoidCollisions: avoid_collisions, collisionPadding: collision_padding, collisionBoundary: collision_boundary,
      sticky: sticky.to_s, hideWhenDetached: hide_when_detached, arrowPadding: arrow_padding, forceMount: force_mount
    }
    @attrs = attrs
    super()
  end

  # @yield the items, groups and separators rendered inside the viewport
  # @return [void]
  # @raise [ArgumentError] at render when used outside {Chadcn::Select}
  def view_template(&block)
    return capture(&block) if collecting?

    state = select_state
    template(data: { chadcn__select_template: "#{state[:base]}-content", chadcn__select_indicator: capture do
      indicator
    end, options: json(@options) }) do
      div(**content_attrs(state)) do
        render Chadcn::Select::ScrollUpButton.new
        tag(:style) { raw(safe(VIEWPORT_CSS)) }
        div(
          data: { radix_select_viewport: "" }, role: "presentation", style: VIEWPORT_STYLE,
          class: cn(VIEWPORT_CLASSES, (VIEWPORT_POPPER_CLASSES if popper?)), &block
        )
        render Chadcn::Select::ScrollDownButton.new
      end
    end
  end

  private

  def popper? = @position == "popper"

  def content_attrs(state)
    attrs = merge_attrs({
                          role: "listbox", id: "#{state[:base]}-content", dir: state[:dir], tabindex: -1,
                          class: cn(CLASSES, (POPPER_CLASSES if popper?)),
                          data: { slot: "select-content", state: "open" }
                        }, @attrs.except(:style))
    attrs.merge(style: [ *base_style, style_string(@attrs[:style]), *(popper_vars if popper?) ].reject_blank.join("; "))
  end

  # The flex layout lets the scroll buttons sit above and below the viewport.
  def base_style
    styles = { "box-sizing" => "border-box", "max-height" => ("100%" unless popper?), "display" => "flex", "flex-direction" => "column",
               "outline" => "none" }
    styles.compact.map { |name, value| "#{name}: #{value}" }
  end

  def popper_vars = POPPER_STYLE_VARS.map { |name, value| "#{name}: #{value}" }
end

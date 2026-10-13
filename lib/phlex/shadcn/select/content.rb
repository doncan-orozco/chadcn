# frozen_string_literal: true

# shadcn SelectContent = Portal + Radix Content + Viewport + scroll buttons. Radix mounts it only while open, so the markup
# ships in an inert <template> that the controller clones into <body> (deviations/select.json). The positioning wrapper
# (item-aligned wrapper or popper wrapper) is created by the controller.
class Phlex::Shadcn::Select::Content < Phlex::Shadcn::Base
  include Phlex::Shadcn::Select::Support

  CLASSES = "relative z-50 max-h-(--radix-select-content-available-height) min-w-[8rem] origin-(--radix-select-content-transform-origin) overflow-x-hidden overflow-y-auto rounded-md border bg-popover text-popover-foreground shadow-md data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=closed]:zoom-out-95 data-[state=open]:animate-in data-[state=open]:fade-in-0 data-[state=open]:zoom-in-95"
  POPPER_CLASSES = "data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1"
  VIEWPORT_CLASSES = "p-1"
  VIEWPORT_POPPER_CLASSES = "h-[var(--radix-select-trigger-height)] w-full min-w-[var(--radix-select-trigger-width)] scroll-my-1"
  VIEWPORT_STYLE = "position: relative; flex: 1 1 0%; overflow: hidden auto;"
  # sel:L740-748
  VIEWPORT_CSS = "[data-radix-select-viewport]{scrollbar-width:none;-ms-overflow-style:none;-webkit-overflow-scrolling:touch;}[data-radix-select-viewport]::-webkit-scrollbar{display:none}"
  POPPER_STYLE_VARS = {
    "--radix-select-content-transform-origin" => "var(--radix-popper-transform-origin)",
    "--radix-select-content-available-width" => "var(--radix-popper-available-width)",
    "--radix-select-content-available-height" => "var(--radix-popper-available-height)",
    "--radix-select-trigger-width" => "var(--radix-popper-anchor-width)",
    "--radix-select-trigger-height" => "var(--radix-popper-anchor-height)"
  }.freeze
  POSITIONS = %w[item-aligned popper].freeze

  # The popper options only apply to the popper position (sel:L438-449); the Radix popper default start alignment is overridden
  # by the shadcn center and collision_padding defaults to CONTENT_MARGIN (sel:L702).
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

  def view_template(&block)
    return capture(&block) if collecting?

    state = select_state
    template(data: { v2__select_template: "#{state[:base]}-content", v2__select_indicator: capture do
      indicator
    end, options: @options.to_json }) do
      div(**content_attrs(state)) do
        render Phlex::Shadcn::Select::ScrollUpButton.new
        tag(:style) { raw(safe(VIEWPORT_CSS)) }
        div(
          data: { radix_select_viewport: "" }, role: "presentation", style: VIEWPORT_STYLE,
          class: cn(VIEWPORT_CLASSES, (VIEWPORT_POPPER_CLASSES if popper?)), &block
        )
        render Phlex::Shadcn::Select::ScrollDownButton.new
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
    attrs.merge(style: [ *base_style, style_string(@attrs[:style]), *(popper_vars if popper?) ].compact_blank.join("; "))
  end

  # sel:L683-690 and L714-726 (the flex layout lets the scroll buttons sit above and below the viewport).
  def base_style
    styles = { "box-sizing" => "border-box", "max-height" => ("100%" unless popper?), "display" => "flex", "flex-direction" => "column",
               "outline" => "none" }
    styles.compact.map { |name, value| "#{name}: #{value}" }
  end

  def popper_vars = POPPER_STYLE_VARS.map { |name, value| "#{name}: #{value}" }
end

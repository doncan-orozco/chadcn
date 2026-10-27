# frozen_string_literal: true

# shadcn ResizablePanel over react-resizable-panels `Panel`: an outer flex item (attributes) around an inner div (`class:`,
# `style:` and the content), as the library renders it.
#
# Sizes follow the library: a Numeric is pixels; a String is parsed with its suffix (`%`, `px`, `rem`, `em`, `vh`, `vw`; none
# means percent). Event `chadcn--resizable:resize` (bubbles, detail `{ size: { asPercentage, inPixels }, id, prevSize }`) is
# dispatched from the outer div.
#
# @example
#   render(Chadcn::Resizable::Panel.new(default_size: "25%", min_size: "10%", collapsible: true)) { "Sidebar" }
class Chadcn::Resizable::Panel < Chadcn::Base
  include Chadcn::Resizable::Support

  # Allowed values of `group_resize_behavior:`.
  # @return [Array<String>]
  RESIZE_BEHAVIORS = %w[preserve-relative-size preserve-pixel-size].freeze
  # Outer style before the flex entries (react-resizable-panels `So`).
  #
  # @api private
  BASE_STYLE = { "min-height" => "0", "max-height" => "100%", "height" => "auto", "min-width" => "0", "max-width" => "100%",
                 "width" => "auto", "border" => "none", "border-width" => "0", "padding" => "0", "margin" => "0" }.freeze
  # Inner div style before the caller style.
  #
  # @api private
  INNER_STYLE = { "max-height" => "100%", "max-width" => "100%", "flex-grow" => "1", "overflow" => "auto" }.freeze

  # @param default_size [Numeric, String, nil] initial size
  # @param min_size [Numeric, String] smallest size (default "0%")
  # @param max_size [Numeric, String] largest size (default "100%")
  # @param collapsible [Boolean] may collapse to `collapsed_size`
  # @param collapsed_size [Numeric, String] size when collapsed (default "0%")
  # @param collapsed_threshold [Numeric, String, nil] default: half the distance between `collapsed_size` and `min_size`
  # @param disabled [Boolean] keeps its size on user input
  # @param group_resize_behavior [String, Symbol] one of {RESIZE_BEHAVIORS}
  # @param id [String, Integer, nil] layout key and element id; a React-style id is generated without it
  # @param class [String, nil] class of the INNER div (no default classes)
  # @param style [String, Hash, nil] style of the INNER div
  # @param attrs [Hash] HTML attributes for the OUTER div
  # @raise [ArgumentError] when `group_resize_behavior:` is not an allowed value
  def initialize(default_size: nil, min_size: "0%", max_size: "100%", collapsible: false, collapsed_size: "0%",
                 collapsed_threshold: nil, disabled: false, group_resize_behavior: "preserve-relative-size", id: nil,
                 class: nil, style: nil, **attrs)
    @default_size = default_size
    @constraints = { defaultSize: default_size, minSize: min_size, maxSize: max_size, collapsible:, collapsedSize: collapsed_size,
                     collapsedThreshold: collapsed_threshold, disabled:,
                     groupResizeBehavior: choice(group_resize_behavior, RESIZE_BEHAVIORS, "group_resize_behavior"),
                     id: id&.then { |given| js_string(given) } }.compact
    @disabled = disabled
    @id = id
    @class = binding.local_variable_get(:class)
    @style = style
    @attrs = attrs
    super()
  end

  # @yield the content of the inner div
  # @return [void]
  def view_template(&)
    group = group_context
    id = resizable_id(@id)
    div(**outer_attrs(id, group)) do
      div(class: @class, style: style_attr(INNER_STYLE, @style, { "touch-action" => touch_action(group) }), &)
    end
  end

  private

  def outer_attrs(id, group)
    merge_attrs({
                  data: { slot: "resizable-panel", disabled: ("true" if @disabled), panel: "true", testid: id,
                          chadcn__resizable_target: "panel", chadcn__resizable_constraints: json(@constraints) },
                  id:,
                  style: style_attr(BASE_STYLE, { "display" => "flex", "flex-basis" => "0", "flex-shrink" => "1", "overflow" => "visible" },
                                    flex_entries(id, group))
                }, without_forced(@attrs, data: %i[disabled panel testid], keys: %i[id style]))
  end

  # The size entry before the layout is known (`yo` in the library): the layout of the group when it names this panel, else the
  # default size as flex-basis, else flex-grow 1.
  def flex_entries(id, group)
    grow = group[:default_layout]&.[](id)
    return { "flex-grow" => grow } if grow && grow != 0
    return { "flex-grow" => "1" } if @default_size.nil?

    { "flex-basis" => (@default_size.is_a?(Numeric) && @default_size != 0 ? "#{js_string(@default_size)}px" : js_string(@default_size)),
      "flex-shrink" => nil }
  end

  def touch_action(group) = group[:orientation] == "horizontal" ? "pan-y" : "pan-x"
end

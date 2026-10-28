# frozen_string_literal: true

# The two wrappers recharts renders in front of the svg, inside `.recharts-wrapper`: the tooltip (component/Tooltip.js,
# TooltipBoundingBox.js:85-90) and the legend (component/Legend.js:129-160). Both are always the same `div`s; the content is what the
# declared `Tooltip::Content` and `Legend::Content` render.
#
# The tooltip wrapper is hidden and empty at rest. With a `default_index:` it holds that category's content and is visible; where it sits
# (`transform`) is the controller's, because it depends on the size of the rendered box, which the server cannot know.
#
# @api private
class Chadcn::Chart::Cartesian::Overlays < Chadcn::Base
  Number = Chadcn::Chart::Shape::Number
  XHTML = "http://www.w3.org/1999/xhtml"
  # The inline style of the tooltip wrapper while no category is active (TooltipBoundingBox.js:60-90).
  HIDDEN_STYLE = { visibility: "hidden", "pointer-events": "none", position: "absolute", top: "0px", left: "0px" }.freeze
  SHOWN_STYLE = HIDDEN_STYLE.merge(visibility: "visible").freeze

  UNITLESS = %i[z-index opacity flex flex-grow flex-shrink order line-height font-weight].freeze

  private_constant :Number, :XHTML, :UNITLESS, :HIDDEN_STYLE, :SHOWN_STYLE

  # @api private
  # @param layout [Chadcn::Chart::Cartesian::Layout]
  # @param declared [Chadcn::Chart::Cartesian::Declared]
  # @param plan [Chadcn::Chart::Cartesian::TooltipPlan, nil] nil without a tooltip
  def initialize(layout:, declared:, plan:)
    @layout = layout
    @declared = declared
    @plan = plan
    super()
  end

  # @return [void]
  def view_template
    tooltip_wrapper if @plan
    legend_wrapper if @declared.legend
  end

  private

  # --- tooltip ------------------------------------------------------------------------------------------------------------

  def tooltip_wrapper
    tooltip = @plan.tooltip
    options = tooltip.options
    shown = @plan.default_entry
    attrs = merge_attrs({ xmlns: XHTML, tabindex: "-1", class: "recharts-tooltip-wrapper", style: wrapper_style(options, shown) }, options[:attrs])
    div(**attrs) { render @plan.content(shown) if shown && tooltip.content_element }
  end

  # `transition` is present only while the tooltip is active and animated (TooltipBoundingBox.js:9-17); `wrapper_style` is spread last, so a
  # property it names replaces the value where the property already is (TooltipBoundingBox.js:82-84).
  def wrapper_style(options, shown)
    base = shown ? SHOWN_STYLE : HIDDEN_STYLE
    base = { transition: transition(options) }.merge(base) if shown && options[:is_animation_active] != false
    style_text(base, options[:wrapper_style])
  end

  # Chromium serializes `transform 400ms ease` as `transform 400ms` (the initial value is dropped).
  def transition(options)
    easing = options[:animation_easing].to_s
    [ "transform", "#{Number.format(options[:animation_duration])}ms", (easing unless easing == "ease") ].compact.join(" ")
  end

  # The style attribute: the base properties with the caller's Hash merged over them, or a String appended.
  def style_text(base, extra)
    base = base.merge(extra.to_h { |name, value| [ name.to_s.tr("_", "-").to_sym, value ] }) if extra.is_a?(Hash)
    text = base.map { |name, value| "#{name}: #{css_value(name, value)};" }.join(" ")
    extra.is_a?(String) ? "#{text} #{extra}" : text
  end

  # A number is pixels, as React DOM writes it, except for the properties that take a plain number.
  def css_value(name, value)
    return value unless value.is_a?(Numeric)

    UNITLESS.include?(name) || value.zero? ? Number.format(value) : "#{Number.format(value)}px"
  end

  # --- legend -------------------------------------------------------------------------------------------------------------

  def legend_wrapper
    legend = @declared.legend
    options = legend.options
    attrs = merge_attrs({ class: "recharts-legend-wrapper", style: legend_style(options) }, options[:attrs])
    div(**attrs) { render legend_content(legend) if legend.content_element }
  end

  # Legend.js:100-125 and `getDefaultPosition` (Legend.js:36-77): the size, then the corner the legend is pinned to, then `wrapper_style`.
  def legend_style(options)
    margin = @layout.margin
    horizontal = options[:layout] == :horizontal
    max_width = @layout.width - margin[:left] - margin[:right]
    width = (horizontal ? (options[:width] || max_width) : options[:width]) || "auto"
    height = options[:height] || "auto"
    style = { position: "absolute", width: width, height: height }.merge(horizontal_position(options, margin)).merge(vertical_position(options, margin))
    style_text(style, options[:wrapper_style])
  end

  def horizontal_position(options, margin)
    return { left: (@layout.width - (options[:width] || 0)) / 2.0 } if options[:align] == :center && options[:layout] == :vertical

    options[:align] == :right ? { right: margin[:right] } : { left: margin[:left] }
  end

  def vertical_position(options, margin)
    case options[:vertical_align]
    when :middle then { top: (@layout.height - options[:legend_height]) / 2.0 }
    when :bottom then { bottom: margin[:bottom] }
    else { top: margin[:top] }
    end
  end

  # The series, in declaration order, sorted by `item_sorter` (legendSelectors.js:6-11) and made unique by value only on request
  # (Legend.js:23-31); the content is cloned with the `Legend`'s own `vertical_align` (component/Legend.js:149-152).
  def legend_content(legend)
    options = legend.options
    items = @declared.series.map { |series| legend_item(series) }
    items = items.each_with_index.sort_by { |item, index| [ item[:value].to_s, index ] }.map(&:first) if options[:item_sorter]
    items = items.uniq { |item| item[:value] } if options[:payload_uniq_by]
    legend.content_element.with(payload: items, vertical_align: options[:vertical_align])
  end

  # `computeLegendPayloadFromBarData` and its siblings (cartesian/Bar.js:45-60, Line.js:56-72, Area.js:67-83).
  def legend_item(series)
    options = series.options
    key = options[:data_key]
    { value: (options[:name] || (key if key.is_a?(String) || key.is_a?(Symbol)))&.to_s, data_key: key.to_s, color: series.legend_color,
      type: options[:legend_type], inactive: options[:hide] }
  end
end

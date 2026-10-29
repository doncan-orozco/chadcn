# frozen_string_literal: true

# The sectors of a pie (polar/Pie.js:285-339 and 566-611): `g.recharts-pie` holding one `g.recharts-pie-sector > g.recharts-shape > path`
# per sector, in the area layer. A pie that is hidden or has nothing to show is the bare `g.recharts-pie`, written in place (right after
# the clip path), where recharts leaves what it does not portal into a layer.
#
# @api private
class Chadcn::Chart::Polar::Drawer::Pie < Chadcn::Chart::Polar::Drawer
  # `Pie` draws in the area layer; `:inline` is the place of an empty pie.
  LAYERS = [ 100, :inline ].freeze

  # @return [void]
  def view_template
    sectors = subject.shapes
    options = subject.series.options
    root = { class: classes("recharts-layer recharts-pie", user_class(options[:attrs])), tabindex: options[:root_tab_index].to_s }
    return g(**root) if sectors.empty? || options[:hide]

    g(**root) do
      g(class: "recharts-layer") { sectors.each { |sector| sector_group(sector, sectors.size) } }
      g(class: "recharts-layer recharts-pie-labels") if subject.series.own_labels?
    end
  end

  # @api private
  # @return [Boolean] whether the pie is drawn in place, not in a layer
  def self.inline?(placed) = placed.shapes.empty? || placed.series.options[:hide]

  private

  def sector_group(sector, count)
    return if sector.start_angle.zero? && sector.end_angle.zero? && count != 1

    g(class: "recharts-layer recharts-pie-sector", tabindex: "-1") do
      g(class: active?(sector) ? "recharts-layer recharts-active-shape" : "recharts-layer recharts-shape") { sector_path(sector) }
    end
  end

  # The sector `default_index:` shows is the active one (`isActive`, polar/Pie.js:314).
  def active?(sector) = canvas.tooltip_entry&.index == sector.index

  def sector_path(sector)
    outline = Chadcn::Chart::Shape::Arc.sector_path(
      cx: sector.cx, cy: sector.cy, inner_radius: sector.inner_radius, outer_radius: sector.outer_radius, start_angle: sector.start_angle,
      end_angle: sector.end_angle, corner_radius: sector.corner_radius
    )
    return unless outline

    path(**sector_attributes(sector), d: outline)
  end

  # The path's attributes (polar/Pie.js:318-323): the sector's presentation, `tabindex`, the item index and id, `recharts-sector` plus the
  # class the pie, row or cell gave.
  def sector_attributes(sector)
    shown = Chadcn::Chart::Polar::PieSectors.presentation(subject.series, sector)
    attrs(shown.except(:class, :class_name), { tabindex: "-1", "data-recharts-item-index": sector.index.to_s, "data-recharts-item-id": item_id },
          { class: classes("recharts-sector", user_class(shown)) })
  end

  def item_id = subject.series.options[:attrs][:id] || "recharts-pie-#{canvas.uid}-#{subject.index}"
end

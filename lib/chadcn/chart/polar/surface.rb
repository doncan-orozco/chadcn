# frozen_string_literal: true

# The `svg.recharts-surface` of a polar chart, drawn from a {Chadcn::Chart::Polar::Layout}: recharts' markup after the browser has settled
# it (dev/port/specs/chart.md, "Structure"). The svg holds one `g` per z-index layer, every layer present whether or not it has content, in
# recharts' order; what a declaration draws goes to the layer recharts draws it in, in order of declaration. The drawing itself is the
# job of the {Chadcn::Chart::Polar::Drawer}s, one family each.
#
# @api private
class Chadcn::Chart::Polar::Surface < Phlex::SVG
  # recharts' `DefaultZIndexes` (zIndex/DefaultZIndexes.js), in drawing order.
  Z_LAYERS = [ -100, -50, 100, 200, 300, 400, 500, 600, 1000, 1100, 1200, 2000 ].freeze
  # A drawer and what it draws.
  Drawing = Data.define(:drawer, :subject)

  private_constant :Z_LAYERS, :Drawing

  # @api private
  # @param layout [Chadcn::Chart::Polar::Layout]
  # @param declared [Chadcn::Chart::Polar::Declared]
  # @param markup [String] what the chart's block wrote itself; placed after the clip path
  # @param tooltip_entry [Object, nil] the entry `default_index:` shows
  # @param uid [String] prefix of the ids this chart writes
  # @param frame [Hash] `title:`, `desc:`, `accessibility_layer:`, `role:`, `tab_index:` and `attrs:` (the attributes of the svg)
  def initialize(layout:, declared:, markup:, tooltip_entry:, uid:, frame:)
    @layout = layout
    @declared = declared
    @markup = markup
    @frame = frame
    @canvas = Chadcn::Chart::Polar::Canvas.new(layout: layout, uid: uid, tooltip_entry: tooltip_entry, counter: Enumerator.produce(1, &:succ))
    @placed = layout.placed.to_h { |placed| [ placed.series, placed ] }
    @drawings = declared.items.flat_map { |item| drawings_for(item) }
    super()
  end

  # @return [void]
  def view_template
    svg(**svg_attributes) do
      title { plain(@frame[:title].to_s) }
      desc { plain(@frame[:desc].to_s) }
      Z_LAYERS.each do |z|
        g(tabindex: "-1", class: "recharts-zIndex-layer_#{z}") { draw(z) }
        in_place if z == -50
      end
    end
  end

  private

  def draw(layer)
    @drawings.each do |drawing|
      next unless drawing.drawer::LAYERS.include?(layer)
      next if inline?(drawing)

      render drawing.drawer.new(subject: drawing.subject, canvas: @canvas, layer: layer)
    end
  end

  # The clip path, then what recharts does not portal into a layer: the markup of the chart and a pie with nothing to draw.
  def in_place
    plot = @layout.plot
    defs do
      clipPath(id: "#{@canvas.uid}-clip") do
        rect(x: Chadcn::Chart::Shape::Number.format(plot[:x]), y: Chadcn::Chart::Shape::Number.format(plot[:y]),
             height: Chadcn::Chart::Shape::Number.format(plot[:height]), width: Chadcn::Chart::Shape::Number.format(plot[:width]))
      end
    end
    @drawings.each { |drawing| render drawing.drawer.new(subject: drawing.subject, canvas: @canvas, layer: :inline) if inline?(drawing) }
    raw(safe(@markup)) unless @markup.empty?
  end

  # Whether the drawing is written in place instead of in its layer (an empty pie).
  def inline?(drawing) = drawing.drawer.respond_to?(:inline?) && drawing.drawer.inline?(drawing.subject)

  def svg_attributes
    number = Chadcn::Chart::Shape::Number
    own = { class: "recharts-surface", width: number.format(@layout.width), height: number.format(@layout.height),
            viewBox: "0 0 #{number.format(@layout.width)} #{number.format(@layout.height)}", style: "width: 100%; height: 100%; display: block;" }
    own = { role: @frame[:role] || "application", tabindex: (@frame[:tab_index] || 0).to_s }.merge(own) if @frame[:accessibility_layer]
    own.merge(@frame[:attrs])
  end

  # --- what each declaration draws -----------------------------------------------------------------------------------------

  def drawings_for(item)
    case item
    when Chadcn::Chart::Pie then pie_drawings(item)
    when Chadcn::Chart::Label then [ Drawing.new(Chadcn::Chart::Polar::Drawer::Label, item) ]
    else []
    end
  end

  def pie_drawings(pie)
    placed = @placed[pie] or return []
    [ Drawing.new(Chadcn::Chart::Polar::Drawer::Pie, placed), *label_drawings(placed) ]
  end

  # The labels of a series, in the order recharts renders them: its own (a pie's `label:`), its label lists, then the labels in its block.
  def label_drawings(placed)
    series = placed.series
    own = series.kind == :pie && series.own_labels? ? [ Drawing.new(Chadcn::Chart::Polar::Drawer::PieLabels, placed) ] : []
    lists = series.label_lists.map { |list| Drawing.new(Chadcn::Chart::Polar::Drawer::LabelList, label_list(list, placed)) }
    own + lists + series.labels.map { |label| Drawing.new(Chadcn::Chart::Polar::Drawer::Label, label) }
  end

  def label_list(list, placed)
    Chadcn::Chart::Polar::Drawer::LabelList::Subject.new(list: list, entries: Chadcn::Chart::Polar::LabelEntries.call(placed))
  end
end

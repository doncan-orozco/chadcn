# frozen_string_literal: true

# The `text` of a recharts `Label` (component/Label.js:262-345) for the drawers of a label list and of a standalone label: the position by
# the polar view box (or the box of a radar point), the text through the formatter, the attributes the caller gave, the class that replaces
# `recharts-label`.
#
# @api private
module Chadcn::Chart::Polar::Drawer::LabelText
  include Chadcn::Chart::Polar::Drawer::TextNodes

  private

  # @param entry [Chadcn::Chart::Polar::LabelEntries::Entry]
  # @param options [Hash] the options of the label or label list
  # @param value [Object] what the label shows
  def label_element(entry, options, value)
    return if value.nil?

    where = entry.view_box ? polar_position(entry, options) : box_position(entry, options)
    return radial_label(where, entry, options, value) if where.is_a?(Chadcn::Chart::Polar::LabelPosition::Radial)

    plain_label(where, entry, options, value)
  end

  def polar_position(entry, options)
    Chadcn::Chart::Polar::LabelPosition.call(view_box: entry.view_box, position: options[:position], offset: options[:offset])
  end

  def box_position(entry, options)
    Chadcn::Chart::Cartesian::LabelPosition.call(box: entry.box, position: options[:position], offset: options[:offset], parent: nil)
  end

  def plain_label(where, entry, options, value)
    custom = options[:attrs]
    anchor = %w[start middle end inherit].include?(custom[:text_anchor].to_s) ? custom[:text_anchor].to_sym : where.horizontal_anchor
    size = where.respond_to?(:width) ? { width: where.width || entry.box[:width], height: where.height || entry.box[:height] } : {}
    box = { width: (format_number(size[:width]) if size[:width]), height: (format_number(size[:height]) if size[:height]) }
    base = attrs(box, { offset: format_number(options[:offset]), fill: options[:fill] || entry.fill || "#808080" },
                 custom.except(:class, :class_name, :text_anchor, :fill))
    class_name = "recharts-text #{user_class(custom) || 'recharts-label'}"
    text_node(label_text(options, value), { x: where.x, y: where.y }, anchor: anchor, vertical: where.vertical_anchor, width: size[:width],
                                                                      angle: options[:angle], base: base, class_name: class_name)
  end

  # `renderRadialLabel`: the text follows the arc of the sector (`textPath`), so it takes no x, y or anchor.
  def radial_label(where, entry, options, value)
    custom = options[:attrs]
    id = canvas.next_id("recharts-radial-line-")
    base = attrs({ fill: options[:fill] || entry.fill, angle: format_number(options[:angle]), offset: format_number(options[:offset]) },
                 custom.except(:class, :class_name, :fill), { class: classes("recharts-radial-bar-label", user_class(custom)), "dominant-baseline": "central" })
    text(**base) do
      defs { path(id: id, d: where.path) }
      textPath("xlink:href": "##{id}") { plain(label_text(options, value)) }
    end
  end

  def label_text(options, value)
    formatter = options[:formatter]
    Chadcn::Chart::Cartesian::Value.text(formatter ? formatter.call(value) : value)
  end
end

# frozen_string_literal: true

# A `LabelList` (component/LabelList.js:60-118) written in a pie, a radar or a radial bar: `g.recharts-label-list` with a label on every
# shape of the series. The list's `fill:` wins over the shape's own (LabelList.js:106).
#
# @api private
class Chadcn::Chart::Polar::Drawer::LabelList < Chadcn::Chart::Polar::Drawer
  include Chadcn::Chart::Polar::Drawer::LabelText

  # The labels are portaled into the label layer (zIndex/DefaultZIndexes.js).
  LAYERS = [ 2000 ].freeze

  # What the drawer draws: the declared list and the entries of the shapes it labels.
  Subject = Data.define(:list, :entries)

  # @return [void]
  def view_template
    options = subject.list.options
    entries = subject.entries
    return if entries.empty?

    g(class: "recharts-layer recharts-label-list") { entries.each { |entry| label_element(entry, options, value_of(entry, options)) } }
  end

  private

  # `getValueByDataKey(entry.payload, dataKey)`, else the shape's value (the last of a range).
  def value_of(entry, options)
    key = options[:data_key]
    return Chadcn::Chart::Cartesian::Value.read(entry.row, key) unless key.nil?

    last = entry.value.is_a?(Array) ? entry.value.last : entry.value
    last if last.nil? || last.is_a?(String) || last.is_a?(Numeric) || last == true || last == false
  end
end

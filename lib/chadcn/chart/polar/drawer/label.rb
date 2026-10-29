# frozen_string_literal: true

# A `Label` (component/Label.js) written in a polar chart or a pie: a text placed by the polar view box of the chart, or around the plot
# for `position: :center` (Label.js:236: a centered label takes the cartesian view box). It is not wrapped in a group.
#
# @api private
class Chadcn::Chart::Polar::Drawer::Label < Chadcn::Chart::Polar::Drawer
  include Chadcn::Chart::Polar::Drawer::LabelText

  LAYERS = [ 2000 ].freeze

  # @return [void]
  def view_template
    options = subject.options
    label_element(entry(options), options, options[:value])
  end

  private

  def entry(options)
    centered = options[:position].to_s == "center"
    Chadcn::Chart::Polar::LabelEntries::Entry.new(value: options[:value], fill: nil, row: nil, view_box: (layout.view_box unless centered),
                                                  box: (layout.plot if centered), attributes: {})
  end
end

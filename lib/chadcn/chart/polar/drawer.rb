# frozen_string_literal: true

# What the drawers of a polar chart's svg share. A drawer draws one declaration (or the placed shapes of one series) into one z-index
# layer of the surface ({Chadcn::Chart::Polar::Surface}); the family it draws is its subclass. `LAYERS` lists the z-index layers a
# drawer draws into, `:inline` the place right after the clip path where recharts renders what it does not portal into a layer.
#
# @api private
class Chadcn::Chart::Polar::Drawer < Phlex::SVG
  Number = Chadcn::Chart::Shape::Number

  private_constant :Number

  # @api private
  # @param subject [Object] the declaration or the placed series the drawer draws
  # @param canvas [Chadcn::Chart::Polar::Canvas]
  # @param layer [Integer, Symbol] the layer being drawn
  def initialize(subject:, canvas:, layer:)
    @subject = subject
    @canvas = canvas
    @layer = layer
    @layout = canvas.layout
    super()
  end

  private

  attr_reader :subject, :canvas, :layout

  def format_number(value) = Number.format(value)

  # The SVG attributes of a shape: nil and false values dropped, later hashes winning, `class_name:` spelled `class:`.
  def attrs(*hashes)
    hashes.compact.each_with_object({}) do |hash, result|
      hash.each do |key, value|
        next if value.nil? || value == false

        result[key == :class_name ? :class : key.to_sym] = value.is_a?(Numeric) ? format_number(value) : value
      end
    end
  end

  # clsx: the class names that are present, joined.
  def classes(*names) = names.flat_map { |name| name.to_s.split }.join(" ")

  # The attributes a caller gave a series or an axis, without the ones that belong to its group (`class:`, `id:`).
  def shape_attrs(hash) = hash.except(:class, :class_name, :id)

  def user_class(hash) = hash[:class] || hash[:class_name]

  # The point at `radius` and `angle` from the center `[x, y]`.
  def point(center, radius, angle) = Chadcn::Chart::Shape::Polar.polar_to_cartesian(center[0], center[1], radius, angle)
end

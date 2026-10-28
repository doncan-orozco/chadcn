# frozen_string_literal: true

# What CarouselPrevious and CarouselNext share: an absolutely placed outline icon Button with a fixed icon and a screen-reader
# label. A part declares only its `arrow` (slot, target, action, icon, placement per orientation); this module owns the kwargs, the
# merge, the locked-disabled rule and the Button render. A module (not a `Chadcn::Base` subclass), so no helper is generated.
#
# @api private
module Chadcn::Carousel::Arrow
  include Chadcn::Carousel::Support

  # @param variant [String, Symbol] any Button variant
  # @param size [String, Symbol] any Button size
  # @param label [String] the screen-reader text (the including part gives it a default)
  # @param attrs [Hash] HTML attributes merged onto the button; a `disabled:` (true or false) is final, the controller never touches it
  def initialize(label:, variant: "outline", size: "icon", **attrs)
    @variant = variant
    @size = size
    @label = label
    attrs[:disabled] = attrs.delete("disabled") if attrs.key?("disabled")
    @attrs = attrs
    super()
  end

  # The content is fixed (a block is ignored, like React's explicit children).
  #
  # @return [void]
  def view_template
    spec = arrow
    attrs = merge_attrs({
                          class: spec.fetch(:placement).fetch(orientation),
                          disabled: true,
                          data: { slot: spec.fetch(:slot), chadcn__carousel_target: spec.fetch(:target), action: spec.fetch(:action) }
                        }, @attrs.compact)
    attrs[:data] = attrs[:data].merge(chadcn__carousel_locked: "true") if locked?
    render(Chadcn::Button.new(variant: @variant, size: @size, **attrs)) do
      render Chadcn::Icon.new(spec.fetch(:icon))
      span(class: "sr-only") { @label }
    end
  end

  private

  # What the including part declares: slot, target, action, icon and the full class string per orientation.
  def arrow = raise(NotImplementedError, "#{self.class} must define a private `arrow` (slot, target, action, icon, placement)")

  # A caller `disabled:` (symbol or string key, true or false; a string key is normalized to the symbol in `initialize`) is final; `nil` counts as not given.
  def locked? = !@attrs[:disabled].nil?
end

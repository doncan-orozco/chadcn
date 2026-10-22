# frozen_string_literal: true

# shadcn Spinner: a spinning +loader-circle+ icon (+role="status"+, label "Loading"). It sets no +data-slot+; attributes go to the icon.
#
# @example
#   Chadcn::Spinner.new(class: "size-6")
class Chadcn::Spinner < Chadcn::Base
  # @param attrs [Hash] attributes for the icon; +class+ is merged with the defaults, +color+ is passed on as +stroke+
  def initialize(**attrs)
    @attrs = attrs
  end

  # Renders the icon (the block is forwarded to {Chadcn::Icon}).
  #
  # @return [void]
  def view_template(&)
    attrs = @attrs.dup
    # lucide Icon consumes `color` as the stroke attribute instead of forwarding it.
    attrs[:stroke] = attrs.delete(:color) if attrs.key?(:color)
    # lucide omits aria-hidden when role/aria props are present; Spinner always passes both.
    defaults = { role: "status", aria: { label: "Loading", hidden: nil }, class: "size-4 animate-spin" }
    render(Chadcn::Icon.new("loader-circle", **merge_attrs(defaults, attrs)), &)
  end
end

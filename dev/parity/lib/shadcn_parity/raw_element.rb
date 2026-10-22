# frozen_string_literal: true

# A raw HTML element of a scenario tree (`_div`, `_a`...). Also usable as the `as_child:` instance of a part, so
# `{ "asChild": true }` over a raw `_a` child goes through the same Radix Slot merge as a component child.
class ShadcnParity::RawElement < Chadcn::Base
  VOID = %w[area base br col embed hr img input link meta source track wbr].freeze

  def initialize(name, **attrs)
    @name = name.to_s
    @attrs = attrs
    super()
  end

  def view_template(&block)
    attrs = merge_attrs({}, @attrs)
    if VOID.include?(@name)
      tag(@name.to_sym, **attrs)
    else
      tag(@name.to_sym, **attrs, &block)
    end
  end
end

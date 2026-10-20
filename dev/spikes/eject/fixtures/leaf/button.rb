# frozen_string_literal: true

# Ejected copy of the gem's Button (leaf component): same constant, host-owned file.
class Phlex::Shadcn::Button < Phlex::Shadcn::Base
  EJECTED = :leaf

  def initialize(**attrs)
    @attrs = attrs
  end

  def view_template(&block)
    button(data_slot: "button", data_ejected: "leaf", **@attrs, &block)
  end
end

# frozen_string_literal: true

# Ejected nested part only: Dialog itself and its other parts keep loading from the gem.
class Phlex::Shadcn::Dialog::Content < Phlex::Shadcn::Base
  include Phlex::Shadcn::Dialog::Support # class-body reference from the override loader into the gem loader, as in a real copy

  EJECTED = :nested

  def view_template(&block)
    div(data_slot: "dialog-content", data_ejected: "nested", &block)
  end
end

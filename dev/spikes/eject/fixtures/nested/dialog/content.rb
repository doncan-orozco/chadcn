# frozen_string_literal: true

# Ejected nested part only: Dialog itself and its other parts keep loading from the gem.
class Chadcn::Dialog::Content < Chadcn::Base
  include Chadcn::Dialog::Support # class-body reference from the override loader into the gem loader, as in a real copy

  EJECTED = :nested

  def view_template(&block)
    div(data_slot: "dialog-content", data_ejected: "nested", &block)
  end
end

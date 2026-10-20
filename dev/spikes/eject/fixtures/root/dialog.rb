# frozen_string_literal: true

# Ejected compound root: a whole component is ejected as one unit (dialog.rb + dialog/), see the decision note.
class Phlex::Shadcn::Dialog < Phlex::Shadcn::Base
  EJECTED = :root

  def view_template(&block)
    div(data_slot: "dialog", data_ejected: "root", &block)
  end
end

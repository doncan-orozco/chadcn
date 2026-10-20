# frozen_string_literal: true

class Phlex::Shadcn::Dialog::Title < Phlex::Shadcn::Base
  EJECTED = :root_title

  def view_template(&block)
    h2(data_slot: "dialog-title", data_ejected: "root-title", &block)
  end
end

# frozen_string_literal: true

class Chadcn::Dialog::Title < Chadcn::Base
  EJECTED = :root_title

  def view_template(&block)
    h2(data_slot: "dialog-title", data_ejected: "root-title", &block)
  end
end

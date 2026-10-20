# frozen_string_literal: true

class Phlex::Shadcn::Dialog::Content < Phlex::Shadcn::Base
  EJECTED = :root_content

  def view_template(&block)
    div(data_slot: "dialog-content", data_ejected: "root-content", &block)
  end
end

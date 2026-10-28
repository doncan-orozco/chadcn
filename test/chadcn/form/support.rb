# frozen_string_literal: true

require "chadcn/test_case"
require "nokogiri"

# Shared helpers of the Chadcn::Form::Field part tests.
module Chadcn::FormSupport
  def field_for(errors: {}, object: { email: "e", bio: "b" })
    binding_object = Chadcn::Form::Binding::Plain.new(scope: :user, object:, errors:)
    Chadcn::Form::Field.new(attribute: :email, binding: binding_object)
  end

  # Renders +part_class+ inside a bound field.
  def render_part(part_class, errors: {}, object: { email: "e", bio: "b" }, **, &block)
    field_for(errors:, object:).call do |field|
      field.render(part_class.new(**), &block)
    end
  end

  def doc(html) = Nokogiri::HTML5.fragment(html)
end

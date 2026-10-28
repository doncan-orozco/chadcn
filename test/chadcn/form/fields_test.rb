# frozen_string_literal: true

require "chadcn/test_case"
require "nokogiri"

class Chadcn::Form::FieldsTest < Chadcn::TestCase
  Address = Struct.new(:street, :city, keyword_init: true)
  User = Struct.new(:email, :address, :addresses, keyword_init: true)

  def user
    User.new(email: "a@b.co", address: Address.new(street: "Main St"),
             addresses: [ Address.new(street: "One"), Address.new(street: "Two", city: "Lima") ])
  end

  def render_form(model = user, **, &)
    html = Chadcn::Form.new(scope: :user, model:, **).call(&)
    Nokogiri::HTML5.fragment(html)
  end

  test "a single object is named and identified like nested attributes" do
    form = render_form do |root|
      root.fields(attribute: :address) { |address| address.field(attribute: :street, &:input) }
    end
    input = form.at_css("input")

    assert_equal "user[address_attributes][street]", input["name"]
    assert_equal "user_address_attributes_street-form-item", input["id"]
    assert_equal "Main St", input["value"]
  end

  test "a collection yields once per element with its index" do
    form = render_form do |root|
      root.fields(attribute: :addresses) { |row| row.field(attribute: :street, &:input) }
    end
    inputs = form.css("input")

    assert_equal(%w[user[addresses_attributes][0][street] user[addresses_attributes][1][street]], inputs.map { |input| input["name"] })
    assert_equal(%w[One Two], inputs.map { |input| input["value"] })
    assert_equal "user_addresses_attributes_1_street-form-item", inputs.last["id"]
  end

  test "an empty collection yields nothing" do
    form = render_form(User.new(addresses: [])) do |root|
      root.fields(attribute: :addresses) { |row| row.field(attribute: :street, &:input) }
    end

    assert_nil form.at_css("input")
  end

  test "index: picks one row of a collection" do
    form = render_form do |root|
      root.fields(attribute: :addresses, index: 1) { |row| row.field(attribute: :street, &:input) }
    end

    assert_equal "user[addresses_attributes][1][street]", form.at_css("input")["name"]
    assert_equal "Two", form.at_css("input")["value"]
  end

  test "index: names the row of a single object, as child_index does" do
    form = render_form do |root|
      root.fields(attribute: :address, index: "NEW_RECORD") { |row| row.field(attribute: :street, &:input) }
    end

    assert_equal "user[address_attributes][NEW_RECORD][street]", form.at_css("input")["name"]
  end

  test "index: that does not select a row of a collection raises naming the attribute" do
    error = assert_raises(ArgumentError) do
      render_form { |root| root.fields(attribute: :addresses, index: "x") { |row| row.field(attribute: :street) } }
    end

    assert_includes error.message, "addresses"
  end

  test "a block is required" do
    assert_raises(ArgumentError) { render_form { |root| root.fields(attribute: :address) } }
  end

  test "nested scopes recurse and keep the namespace" do
    tree = User.new(addresses: [ User.new(addresses: [ Address.new(city: "Cusco") ]) ])
    form = render_form(tree, namespace: "signup") do |root|
      root.fields(attribute: :addresses) do |row|
        row.fields(attribute: :addresses) { |inner| inner.field(attribute: :city, &:input) }
      end
    end
    input = form.at_css("input")

    assert_equal "user[addresses_attributes][0][addresses_attributes][0][city]", input["name"]
    assert_equal "signup_user_addresses_attributes_0_addresses_attributes_0_city-form-item", input["id"]
  end

  test "the root binding is back after the block, so fields beside it keep their names" do
    form = render_form do |root|
      root.fields(attribute: :address) { |address| address.field(attribute: :street, &:input) }
      root.field(attribute: :email, &:input)
    end

    assert_equal(%w[user[address_attributes][street] user[email]], form.css("input").map { |input| input["name"] })
  end

  test "the scope offers field, fields and the nested binding" do
    scope = nil
    render_form { |root| root.fields(attribute: :address) { |address| scope = address } }

    assert_instance_of Chadcn::Form::Fields, scope
    assert_equal "user[address_attributes][street]", scope.form_binding.name_for(:street)
    %i[field fields].each { |helper| assert_respond_to scope, helper }
  end

  test "errors of a row come from the parent errors keyed like Rails index_errors" do
    errors = { "addresses[1].street": [ "is blank" ], "address.street": [ "is too short" ] }
    form = render_form(errors:) do |root|
      root.fields(attribute: :addresses) do |row|
        row.field(attribute: :street) do |field|
          field.input
          field.error
        end
      end
      root.fields(attribute: :address) { |address| address.field(attribute: :street, &:error) }
    end
    messages = form.css("[data-slot=field-error]")

    assert_equal([ "", "is blank", "is too short" ], messages.map { |message| message.text.strip })
    assert_equal "true", form.css("input").last["aria-invalid"]
    assert_equal "false", form.css("input").first["aria-invalid"]
  end

  test "an explicit hidden input of the binding is rendered after the row's own inputs" do
    identified = Class.new(Chadcn::Form::Binding::Plain) do
      def hidden_fields = { id: 5 }
    end
    root_binding = Class.new(Chadcn::Form::Binding::Plain) do
      define_method(:nested) do |attribute, object:, index: nil, **|
        identified.new(scope: [ "user", "#{attribute}_attributes", *index&.to_s ], object:)
      end
    end.new(scope: :user, object: user)
    html = Chadcn::Form.new(binding: root_binding).call do |root|
      root.fields(attribute: :address) { |address| address.field(attribute: :street, &:input) }
    end
    hidden = Nokogiri::HTML5.fragment(html).at_css("input[type=hidden][name='user[address_attributes][id]']")

    assert_equal "5", hidden["value"]
    assert_equal "user_address_attributes_id", hidden["id"]
    assert_operator html.index("[street]"), :<, html.index("[id]")
  end

  test "a binding with no hidden fields renders none" do
    form = render_form { |root| root.fields(attribute: :address) { |address| address.field(attribute: :street, &:input) } }

    assert_nil form.at_css("input[type=hidden]")
  end
end

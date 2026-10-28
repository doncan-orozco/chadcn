# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Form::Binding::PlainTest < Chadcn::TestCase
  Person = Struct.new(:first_name, :email, keyword_init: true)

  def plain(**) = Chadcn::Form::Binding::Plain.new(scope: :user, **)

  test "includes the protocol and defaults" do
    binding_object = plain

    assert_kind_of Chadcn::Form::Binding, binding_object
    assert_equal "post", binding_object.http_method
    assert_nil binding_object.action
    assert_nil binding_object.csrf_token
  end

  test "name_for scopes and handles multiple" do
    assert_equal "user[email]", plain.name_for(:email)
    assert_equal "user[tags][]", plain.name_for(:tags, multiple: true)
    assert_equal "email", Chadcn::Form::Binding::Plain.new(scope: nil).name_for(:email)
    assert_equal "tags[]", Chadcn::Form::Binding::Plain.new(scope: nil).name_for(:tags, multiple: true)
  end

  test "id_for joins scope and attribute, with namespace" do
    assert_equal "user_email", plain.id_for(:email)
    assert_equal "signup_user_email", plain(namespace: "signup").id_for(:email)
    assert_equal "email", Chadcn::Form::Binding::Plain.new(scope: nil).id_for(:email)
  end

  test "value_for reads Struct, symbol Hash, string Hash and nil" do
    assert_equal "a", plain(object: Person.new(email: "a")).value_for(:email)
    assert_equal "b", plain(object: { email: "b" }).value_for(:email)
    assert_equal "c", plain(object: { "email" => "c" }).value_for(:email)
    assert_nil plain.value_for(:email)
  end

  test "errors_for accepts symbol and string keys and answers messages" do
    assert_equal [ "x" ], plain(errors: { email: [ "x" ] }).errors_for(:email)
    assert_equal [ "y" ], plain(errors: { "email" => "y" }).errors_for(:email)
    assert_equal [], plain(errors: {}).errors_for(:email)
    assert_equal [], plain(errors: nil).errors_for(:email)
  end

  test "errors_for works with any object answering []" do
    lookup = Object.new
    def lookup.[](key) = key == :email ? [ "z" ] : []

    assert_equal [ "z" ], plain(errors: lookup).errors_for(:email)
  end

  test "label_for humanizes" do
    assert_equal "First name", plain.label_for(:first_name)
  end

  test "http_method is a downcased string" do
    assert_equal "patch", plain(http_method: :PATCH).http_method
  end

  test "nested object" do
    child = plain(namespace: "n").nested(:address, object: { street: "S" })

    assert_equal "user[address_attributes][street]", child.name_for(:street)
    assert_equal "n_user_address_attributes_street", child.id_for(:street)
    assert_equal "S", child.value_for(:street)
  end

  test "nested collection row carries index and errors" do
    child = plain.nested(:addresses, object: nil, index: 1, errors: { city: [ "bad" ] })

    assert_equal "user[addresses_attributes][1][city]", child.name_for(:city)
    assert_equal "user_addresses_attributes_1_city", child.id_for(:city)
    assert_equal [ "bad" ], child.errors_for(:city)
  end

  test "a nested row derives its errors from the parent errors keyed like index_errors" do
    parent = plain(errors: { "addresses[1].city": [ "bad" ], "address.city": [ "short" ], city: [ "root" ] })

    assert_equal [ "bad" ], parent.nested(:addresses, object: nil, index: 1).errors_for(:city)
    assert_empty parent.nested(:addresses, object: nil, index: 0).errors_for(:city)
    assert_equal [ "short" ], parent.nested(:address, object: nil).errors_for(:city)
  end

  test "a nested row reads errors of an ActiveModel::Errors-like lookup through []" do
    lookup = Class.new { def [](key) = key == :"addresses[0].city" ? [ "bad" ] : [] }.new

    assert_equal [ "bad" ], plain(errors: lookup).nested(:addresses, object: nil, index: 0).errors_for(:city)
  end

  test "a Plain binding has no hidden fields" do
    assert_empty plain.nested(:address, object: { id: 1 }).hidden_fields
  end

  test "an array scope nests names" do
    nested = Chadcn::Form::Binding::Plain.new(scope: %i[a b])

    assert_equal "a[b][c]", nested.name_for(:c)
  end
end

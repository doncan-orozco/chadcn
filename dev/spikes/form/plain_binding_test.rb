# frozen_string_literal: true

# Spike for the form epic: proves that a plain Ruby binding computes names, ids, values and errors with no Rails.
# Decision and consequences: dev/decisions/form.md.
#
#   env -u BUNDLE_GEMFILE bundle exec ruby -Ilib -Itest dev/spikes/form/plain_binding_test.rb
require "minitest/autorun"
require_relative "binding"

class PlainBindingTest < Minitest::Test
  User = Struct.new(:email, :name, :admin)
  Address = Struct.new(:street, :city)

  def setup
    @user = User.new("ada@example.com", "Ada", true)
    @errors = { email: [ "is invalid", "is too short" ], "name" => [ "can't be blank" ] }
    @binding = FormSpike::Plain.new(scope: "user", object: @user, errors: @errors, action: "/users", csrf_token: "tok")
  end

  def test_name_follows_the_rails_convention
    assert_equal "user[email]", @binding.name_for(:email)
    assert_equal "user[tags][]", @binding.name_for(:tags, multiple: true)
  end

  def test_id_joins_scope_and_attribute_with_underscores
    assert_equal "user_email", @binding.id_for(:email)
  end

  def test_value_is_read_from_a_struct_and_from_a_hash
    assert_equal "ada@example.com", @binding.value_for(:email)
    hash_binding = FormSpike::Plain.new(scope: "user", object: { email: "h@example.com" })

    assert_equal "h@example.com", hash_binding.value_for(:email)
    assert_equal "h@example.com", FormSpike::Plain.new(scope: "user", object: { "email" => "h@example.com" }).value_for(:email)
  end

  def test_a_false_value_is_kept
    assert_same false, FormSpike::Plain.new(scope: "user", object: { admin: false }).value_for(:admin)
  end

  def test_value_is_nil_without_an_object
    assert_nil FormSpike::Plain.new(scope: "user").value_for(:email)
  end

  def test_errors_accept_symbol_and_string_keys_and_default_to_empty
    assert_equal [ "is invalid", "is too short" ], @binding.errors_for(:email)
    assert_equal [ "can't be blank" ], @binding.errors_for(:name)
    assert_empty @binding.errors_for(:admin)
  end

  def test_label_is_humanized_from_the_attribute
    assert_equal "Email", @binding.label_for(:email)
    assert_equal "First name", @binding.label_for(:first_name)
  end

  def test_action_method_and_token_are_carried_as_given
    assert_equal "/users", @binding.action
    assert_equal "post", @binding.http_method
    assert_equal "tok", @binding.csrf_token
  end

  def test_nested_object_naming_matches_rails_nested_attributes
    address = @binding.nested(:address, object: Address.new("Main St", "Lima"))

    assert_equal "user[address_attributes][street]", address.name_for(:street)
    assert_equal "user_address_attributes_street", address.id_for(:street)
    assert_equal "Main St", address.value_for(:street)
  end

  def test_nested_collection_naming_carries_the_index
    row = @binding.nested(:addresses, object: Address.new("Main St", "Lima"), index: 1, errors: { city: [ "is blank" ] })

    assert_equal "user[addresses_attributes][1][city]", row.name_for(:city)
    assert_equal "user_addresses_attributes_1_city", row.id_for(:city)
    assert_equal [ "is blank" ], row.errors_for(:city)
  end

  def test_namespace_prefixes_the_id_and_nested_bindings_carry_it
    scoped = FormSpike::Plain.new(scope: "user", object: @user, namespace: "signup")
    row = scoped.nested(:addresses, object: Address.new("Main St", "Lima"), index: 0)

    assert_equal "signup_user_email", scoped.id_for(:email)
    assert_equal "user[email]", scoped.name_for(:email)
    assert_equal "signup_user_addresses_attributes_0_city", row.id_for(:city)
  end

  def test_the_protocol_is_answered_in_full
    FormSpike::METHODS.each { |name| assert_respond_to @binding, name }
  end
end

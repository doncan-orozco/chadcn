# frozen_string_literal: true

# Spike for the form epic: proves that a real ActionView::Helpers::FormBuilder answers what a Rails binding needs, in
# process and without a database. Rails is required here only (as test/engine/engine_helper.rb does for the engine suite).
# Decision and consequences: dev/decisions/form.md.
#
#   env -u BUNDLE_GEMFILE bundle exec ruby -Ilib -Itest dev/spikes/form/rails_binding_test.rb
require "rails"
require "action_controller"
require "action_view"
require "active_model"
require "minitest/autorun"

class RailsBindingTest < Minitest::Test
  # Nested in the test class, so the model names are pinned to what a host app would have (User, Address).
  class Address
    include ActiveModel::Model

    def self.model_name = ActiveModel::Name.new(self, nil, "Address")

    attr_accessor :street, :id

    def persisted? = id.present?
  end

  class User
    include ActiveModel::Model

    def self.model_name = ActiveModel::Name.new(self, nil, "User")

    attr_accessor :email, :id, :addresses

    validates :email, presence: true

    def persisted? = id.present?

    def addresses_attributes=(attributes)
      @addresses = attributes
    end
  end

  ROUTES = ActionDispatch::Routing::RouteSet.new.tap { |set| set.draw { resources :users } }

  # The view context a controller would give the builder: url helpers, CSRF and the form helpers.
  class View < ActionView::Base
    include ROUTES.url_helpers
    include ROUTES.mounted_helpers

    def protect_against_forgery? = true

    def form_authenticity_token(**) = "spike-token"

    def request_forgery_protection_token = :authenticity_token

    def default_url_options = {}
  end

  def view
    @view ||= View.with_empty_template_cache.with_view_paths([])
  end

  # Runs the block with the FormBuilder form_with creates and returns [builder, rendered form html].
  def with_builder(model, **options)
    builder = nil
    html = view.form_with(model:, **options) do |form|
      builder = form
      ""
    end
    [ builder, html ]
  end

  def test_field_name_and_field_id_follow_the_convention
    builder, = with_builder(User.new)

    assert_equal "user[email]", builder.field_name(:email)
    assert_equal "user[tags][]", builder.field_name(:tags, multiple: true)
    assert_equal "user_email", builder.field_id(:email)
  end

  def test_new_record_posts_to_the_collection_path_without_method_override
    builder, html = with_builder(User.new)

    assert_includes html, 'action="/users"'
    assert_includes html, 'method="post"'
    refute_includes html, 'name="_method"'
    assert_equal "/users", view.polymorphic_path(builder.object)
  end

  def test_persisted_record_patches_to_the_member_path_with_the_method_hidden_input
    user = User.new(id: 7)
    builder, html = with_builder(user)

    assert_includes html, 'action="/users/7"'
    assert_match(/<input(?=[^>]*type="hidden")(?=[^>]*value="patch")[^>]*name="_method"/, html)
    assert_equal "/users/7", view.polymorphic_path(builder.object)
  end

  def test_csrf_token_is_a_hidden_input_named_after_the_protection_token
    _, html = with_builder(User.new)

    assert_match(/<input(?=[^>]*type="hidden")(?=[^>]*value="spike-token")[^>]*name="authenticity_token"/, html)
  end

  def test_label_text_comes_from_human_attribute_name_and_the_locale
    assert_equal "Email", User.human_attribute_name(:email)

    I18n.backend.store_translations(:en, activemodel: { attributes: { user: { email: "Work email" } } })

    assert_equal "Work email", User.human_attribute_name(:email)
  ensure
    I18n.backend.reload!
  end

  def test_errors_and_value_are_read_from_the_model
    user = User.new(email: "")
    user.valid?
    builder, = with_builder(user)

    assert_equal [ "can't be blank" ], builder.object.errors[:email]
    assert_equal "", builder.object.email
  end

  def test_fields_for_names_nested_attributes_with_the_index_and_the_hidden_id
    user = User.new(id: 1, addresses: [ Address.new(id: 5, street: "Main St"), Address.new(street: "Side St") ])
    builder, = with_builder(user)
    html = builder.fields_for(:addresses, user.addresses) { |address| address.text_field(:street) + address.field_name(:street) }

    assert_includes html, 'name="user[addresses_attributes][0][street]"'
    assert_includes html, 'name="user[addresses_attributes][1][street]"'
    assert_includes html, 'id="user_addresses_attributes_0_street"'
    assert_match(/<input(?=[^>]*type="hidden")(?=[^>]*value="5")[^>]*name="user\[addresses_attributes\]\[0\]\[id\]"/, html)
    refute_includes html, 'name="user[addresses_attributes][1][id]"'
  end

  def test_a_get_form_has_no_authenticity_token
    html = view.form_with(url: "/search", method: :get) { "" }

    refute_includes html, 'name="authenticity_token"'
  end

  def test_fields_for_emits_the_hidden_id_after_the_child_inputs
    user = User.new(id: 1, addresses: [ Address.new(id: 5, street: "Main St") ])
    builder, = with_builder(user)
    html = builder.fields_for(:addresses, user.addresses) { |address| address.text_field(:street) }

    assert_operator html.index("[street]"), :<, html.index("[id]")
  end

  def test_a_builder_built_directly_answers_the_same_names
    builder = ActionView::Helpers::FormBuilder.new("user", User.new, view, {})

    assert_equal "user[email]", builder.field_name(:email)
    assert_equal "user_email", builder.field_id(:email)
  end

  def test_the_builder_exposes_the_calls_the_rails_binding_forwards
    builder, = with_builder(User.new)

    %i[field_name field_id fields_for object object_name].each { |call| assert_respond_to builder, call }
  end
end

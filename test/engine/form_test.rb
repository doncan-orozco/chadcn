# frozen_string_literal: true

require_relative "engine_helper"
require "action_controller"
require "action_view"
require "active_model"
require "nokogiri"

# Chadcn::Engine::FormBinding over a real ActionView view context (url helpers, CSRF) and ActiveModel models, no database.
class EngineTest::FormBinding < Minitest::Test
  class Address
    include ActiveModel::Model

    def self.model_name = ActiveModel::Name.new(self, nil, "Address")

    attr_accessor :street, :id

    validates :street, presence: true

    def persisted? = id.present?
  end

  class User
    include ActiveModel::Model

    def self.model_name = ActiveModel::Name.new(self, nil, "User")

    attr_accessor :email, :nickname, :id, :addresses

    validates :email, presence: true
    validates :nickname, presence: true, if: -> { false }

    def persisted? = id.present?

    def addresses_attributes=(rows)
      @addresses = rows
    end
  end

  # No route is drawn for it.
  class Ghost
    include ActiveModel::Model

    def self.model_name = ActiveModel::Name.new(self, nil, "Ghost")

    def persisted? = false
  end

  ROUTES = ActionDispatch::Routing::RouteSet.new.tap { |set| set.draw { resources :users } }

  # What a controller gives the view: url helpers and the forgery protection hooks.
  class View < ActionView::Base
    include ROUTES.url_helpers

    attr_accessor :forgery

    def protect_against_forgery? = forgery != false

    def form_authenticity_token(**) = "token-123"

    def request_forgery_protection_token = :authenticity_token

    def default_url_options = {}
  end

  def view = @view ||= View.with_empty_template_cache.with_view_paths([])

  def binding_for(model = User.new, **options) = Chadcn::Engine::FormBinding.new(view_context: view, model:, **options)

  def render_form(model = User.new, **options)
    form_binding = binding_for(model, **options)
    html = Chadcn::Form.new(binding: form_binding).call do |form|
      form.field(attribute: :email) do |field|
        field.label
        field.input(type: "email", required: form_binding.required?(:email))
        field.error
      end
      form.field(attribute: :nickname) { |field| field.input(required: form_binding.required?(:nickname)) }
    end
    Nokogiri::HTML5.fragment(html)
  end

  def teardown = I18n.backend.reload!

  def test_a_new_model_posts_to_its_collection_with_a_token_and_no_method_override
    form = render_form.at_css("form")

    assert_equal "/users", form["action"]
    assert_equal "post", form["method"]
    assert_nil form.at_css("input[name=_method]")
    assert_equal "token-123", form.at_css("input[type=hidden][name=authenticity_token]")["value"]
  end

  def test_a_persisted_model_patches_its_member_path_through_the_method_override
    form = render_form(User.new(id: 7)).at_css("form")

    assert_equal "/users/7", form["action"]
    assert_equal "post", form["method"]
    assert_equal "patch", form.at_css("input[type=hidden][name=_method]")["value"]
  end

  def test_url_and_method_win_over_the_model
    form = render_form(User.new(id: 7), url: "/members", method: :put).at_css("form")

    assert_equal "/members", form["action"]
    assert_equal "put", form.at_css("input[name=_method]")["value"]
  end

  def test_a_get_form_has_no_token
    form = render_form(url: "/search", method: :get).at_css("form")

    assert_equal "get", form["method"]
    assert_nil form.at_css("input[name=authenticity_token]")
  end

  def test_no_token_when_forgery_protection_is_off
    view.forgery = false

    assert_nil render_form.at_css("input[name=authenticity_token]")
  end

  def test_the_field_gets_rails_name_and_id_and_the_form_item_aria
    input = render_form.at_css("input[type=email]")

    assert_equal "user[email]", input["name"]
    assert_equal "user_email-form-item", input["id"]
    assert_equal "user_email-form-item-description", input["aria-describedby"]
    assert_equal "false", input["aria-invalid"]
  end

  def test_names_follow_multiple_and_the_namespace
    form_binding = binding_for(namespace: "signup")

    assert_equal "user[tags][]", form_binding.name_for(:tags, multiple: true)
    assert_equal "signup_user_email", form_binding.id_for(:email)
  end

  def test_scope_overrides_the_param_key
    assert_equal "member[email]", binding_for(scope: :member).name_for(:email)
  end

  def test_label_is_human_attribute_name_then_the_helpers_translation
    assert_equal "Email", render_form.at_css("label").text

    I18n.backend.store_translations(:en, helpers: { label: { user: { email: "Work email" } } })

    assert_equal "Work email", render_form.at_css("label").text
  end

  def test_label_of_a_nested_row_uses_the_dotted_association_scope_like_label
    I18n.backend.store_translations(:en, helpers: { label: { user: { addresses: { street: "Street line" } } } })
    row = binding_for(User.new(id: 1)).nested(:addresses, object: Address.new, index: 0)

    assert_equal "Street line", row.label_for(:street)
  end

  def test_required_comes_from_an_unconditional_presence_validator
    form = render_form

    assert_equal "", form.at_css("input[type=email]")["required"]
    assert_nil form.at_css("input[name='user[nickname]']")["required"]
  end

  def test_errors_and_values_are_read_from_the_model
    user = User.new(email: "")
    user.valid?
    input = render_form(user).at_css("input[type=email]")

    assert_equal "true", input["aria-invalid"]
    assert_equal [ "can't be blank" ], binding_for(user).errors_for(:email)
    assert_equal "can't be blank", render_form(user).at_css("[data-slot=field-error]").text.strip
  end

  def test_a_nested_collection_row_is_named_and_identified_like_fields_for
    user = User.new(id: 1)
    row = binding_for(user, namespace: "signup").nested(:addresses, object: Address.new(street: "Main St"), index: 1)

    assert_equal "user[addresses_attributes][1][street]", row.name_for(:street)
    assert_equal "signup_user_addresses_attributes_1_street", row.id_for(:street)
    assert_equal "Main St", row.value_for(:street)
  end

  def test_a_nested_single_model_without_a_writer_has_no_attributes_suffix
    row = binding_for.nested(:profile, object: Address.new)

    assert_equal "user[profile][street]", row.name_for(:street)
  end

  def test_a_model_without_a_route_raises_what_form_with_raises_naming_the_class
    ghost = Ghost.new
    expected = assert_raises(NoMethodError) { view.form_with(model: ghost) { "" } }
    error = assert_raises(NoMethodError) { render_form(ghost) }

    assert_equal expected.class, error.class
    assert_includes error.message, "ghost"
    assert_includes error.message, "_path"
  end

  def test_without_model_or_scope_it_raises
    error = assert_raises(ArgumentError) { Chadcn::Engine::FormBinding.new(view_context: view) }

    assert_includes error.message, "model: or scope:"
  end

  def test_scope_only_binding_has_no_action
    form_binding = Chadcn::Engine::FormBinding.new(view_context: view, scope: :search)

    assert_nil form_binding.action
    assert_equal "post", form_binding.http_method
    assert_nil form_binding.value_for(:q)
    assert_equal [], form_binding.errors_for(:q)
    assert_equal "Q", form_binding.label_for(:q)
  end
end

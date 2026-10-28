# frozen_string_literal: true

require "action_view"

module Chadcn
  class Engine
    # A {Chadcn::Form::Binding} over a real +ActionView::Helpers::FormBuilder+, for hosts that run Rails: names and ids are
    # Rails' own (+field_name+, +field_id+, so +multiple:+, indexes and +namespace:+ are exact), the action comes from the route
    # of the model, the verb from +persisted?+, the CSRF token from the view context, the errors and values from the model and
    # the labels from the +helpers.label.*+ translations before +human_attribute_name+.
    #
    # It builds its own builder and never wraps +form_with+: {Chadcn::Form} renders the only +<form>+, so using it inside
    # +form_with+ nests two forms.
    #
    # @example
    #   render Chadcn::Form.new(binding: Chadcn::Engine::FormBinding.new(view_context: helpers, model: @user)) do |form|
    #     form.field(attribute: :email) { |field| field.label; field.input(type: "email", required: field.form_binding.required?(:email)) }
    #   end
    #
    # @api private
    class FormBinding
      include Chadcn::Form::Binding

      # Matches the nested part of a builder scope (+user[addresses_attributes][0]+) the way Rails' +label+ helper does.
      NESTED_SCOPE = /\[(.*)_attributes\]\[\d+\]/
      private_constant :NESTED_SCOPE

      # @return [Object, nil] the model the form is bound to
      attr_reader :model

      # @param view_context [ActionView::Base] the rendering view (+helpers+ under phlex-rails, +self+ in ERB); gives url helpers and CSRF
      # @param model [ActiveModel::Naming, nil] the model; gives the default scope, the route, the verb, the values and the errors
      # @param scope [Symbol, String, nil] the name prefix; defaults to the +param_key+ of the model
      # @param url [String, nil] the action; defaults to +polymorphic_path(model)+
      # @param method [String, Symbol, nil] the verb; defaults to +patch+ for a persisted model, else +post+
      # @param namespace [String, nil] prefix of every generated id
      # @raise [ArgumentError] without +model:+ and +scope:+
      def initialize(view_context:, model: nil, scope: nil, url: nil, method: nil, namespace: nil)
        @view_context = view_context
        @model = model
        @scope = (scope || model&.model_name&.param_key || raise(ArgumentError, "FormBinding needs model: or scope:")).to_s
        @url = url
        @method = method
        @namespace = namespace
        @builder = ::ActionView::Helpers::FormBuilder.new(@scope, model, view_context, { namespace: }.compact)
      end

      # @param attribute [Symbol, String]
      # @param multiple [Boolean]
      # @return [String]
      def name_for(attribute, multiple: false) = @builder.field_name(attribute, multiple:)

      # @param attribute [Symbol, String]
      # @return [String]
      def id_for(attribute) = @builder.field_id(attribute)

      # @param attribute [Symbol, String]
      # @return [Object, nil]
      def value_for(attribute) = @model&.public_send(attribute)

      # @param attribute [Symbol, String]
      # @return [Array<String>] the messages of +model.errors+
      def errors_for(attribute)
        return [] unless @model.respond_to?(:errors)

        Array(@model.errors[attribute.to_sym]).map(&:to_s)
      end

      # The +helpers.label.<scope>.<attribute>+ translation, then +human_attribute_name+, as Rails' +label+.
      #
      # @param attribute [Symbol, String]
      # @return [String]
      def label_for(attribute)
        translated = ::I18n.t("#{@scope.gsub(NESTED_SCOPE, '.\1')}.#{attribute}", scope: "helpers.label", default: "")
        return translated unless translated.empty?

        @model.class.respond_to?(:human_attribute_name) ? @model.class.human_attribute_name(attribute) : attribute.to_s.tr("_", " ").capitalize
      end

      # Whether a presence validator (without +if:+/+unless:+) applies to the attribute, for +required+ on a control.
      #
      # @param attribute [Symbol, String]
      # @return [Boolean]
      def required?(attribute)
        return false unless @model.class.respond_to?(:validators_on)

        @model.class.validators_on(attribute.to_sym).any? do |validator|
          validator.is_a?(::ActiveModel::Validations::PresenceValidator) && !validator.options.key?(:if) && !validator.options.key?(:unless)
        end
      end

      # A binding for a nested model: +user[addresses_attributes][0][street]+ (+user[address_attributes][street]+ for a single
      # model; Rails appends +_attributes+ only when the model defines the writer). It carries the namespace and the view context.
      #
      # @param attribute [Symbol, String] the association
      # @param object [Object, nil] the nested model
      # @param index [Integer, String, nil] the row of a collection
      # @param errors [#[]] ignored: the errors are read from +object.errors+
      # @return [Chadcn::Engine::FormBinding]
      def nested(attribute, object:, index: nil, errors: {})
        suffix = @model.respond_to?(:"#{attribute}_attributes=") ? "#{attribute}_attributes" : attribute.to_s
        self.class.new(view_context: @view_context, model: object, scope: "#{@scope}[#{suffix}]#{"[#{index}]" if index}",
                       namespace: @namespace)
      end

      # @return [String, nil] +url:+, else +polymorphic_path(model)+
      # @raise [NoMethodError] when the model has no route, as +form_with+ raises
      def action
        @url || (@model && @view_context.polymorphic_path(@model))
      end

      # @return [String]
      def http_method
        (@method || (persisted? ? "patch" : "post")).to_s.downcase
      end

      # @return [String, nil] nil when forgery protection is off or the form is a GET
      def csrf_token
        return unless @view_context.protect_against_forgery? && http_method != "get"

        @view_context.form_authenticity_token(form_options: { action:, method: http_method })
      end

      private

      def persisted? = @model.respond_to?(:persisted?) && @model.persisted?
    end
  end
end

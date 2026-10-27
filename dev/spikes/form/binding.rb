# frozen_string_literal: true

# Throwaway prototype of the Binding protocol that item #37 builds in lib/chadcn/form/. It only exists to prove, with tests,
# that the protocol can be answered by a plain Ruby object (Plain) and by a real ActionView::Helpers::FormBuilder (Rails)
# without a database. Decision and consequences: dev/decisions/form.md.
module FormSpike
  # The questions a bound Field asks. Every binding answers the same ones, so Form::Field never knows which one it has.
  METHODS = %i[name_for id_for value_for errors_for label_for action http_method csrf_token nested].freeze

  # Plain Ruby: a scope (`user`), any object that answers the attribute readers (Struct, Hash) and a hash of errors.
  class Plain
    attr_reader :action, :http_method, :csrf_token

    def initialize(scope:, object: nil, errors: {}, action: nil, http_method: "post", csrf_token: nil)
      @path = Array(scope).map(&:to_s)
      @object = object
      @errors = errors
      @action = action
      @http_method = http_method
      @csrf_token = csrf_token
    end

    def name_for(attribute, multiple: false)
      head, *tail = @path + [ attribute.to_s ]
      "#{head}#{tail.map { |segment| "[#{segment}]" }.join}#{'[]' if multiple}"
    end

    def id_for(attribute)
      (@path + [ attribute.to_s ]).join("_")
    end

    def value_for(attribute)
      case @object
      when nil then nil
      when Hash then @object[attribute.to_sym] || @object[attribute.to_s]
      else @object.public_send(attribute)
      end
    end

    def errors_for(attribute)
      Array(@errors[attribute.to_sym] || @errors[attribute.to_s])
    end

    def label_for(attribute)
      attribute.to_s.tr("_", " ").capitalize
    end

    # A nested binding: `user[addresses_attributes][0][street]`.
    def nested(attribute, object:, index: nil, errors: {})
      self.class.new(scope: @path + [ "#{attribute}_attributes", *index&.to_s ], object:, errors:)
    end
  end
end

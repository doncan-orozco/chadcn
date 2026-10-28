# frozen_string_literal: true

require "chadcn/test_case"

class Chadcn::Form::BindingTest < Chadcn::TestCase
  Bare = Class.new { include Chadcn::Form::Binding }

  test "every protocol message raises NotImplementedError on a bare includer" do
    bare = Bare.new
    calls = { name_for: [ :a ], id_for: [ :a ], value_for: [ :a ], errors_for: [ :a ], label_for: [ :a ], action: [], http_method: [],
              csrf_token: [] }

    calls.each do |message, args|
      assert_raises(NotImplementedError, message.to_s) { bare.public_send(message, *args) }
    end
    assert_raises(NotImplementedError) { bare.nested(:a, object: nil) }
  end
end

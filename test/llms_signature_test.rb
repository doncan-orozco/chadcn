# frozen_string_literal: true

require "test_helper"
require "yard"
require_relative "../dev/llms/signature"

# `Phlex::Shadcn::Llms::Signature` renders the parameter lists of llms.txt, llms-full.txt, SKILL.md and test/fixtures/public_api.txt from
# YARD's raw default slices. These tests pin that the text is the same on every Ruby the gem supports.
class LlmsSignatureTest < Minitest::Test
  Signature = Phlex::Shadcn::Llms::Signature

  # Every keyword-default literal the gem may write, as the source of a method: YARD slices it from the text and keeps a different
  # trailing delimiter per Ruby, so the renderer must give one exact string wherever this runs.
  SIGNATURE_SOURCE = <<~RUBY
    class Sample
      def call(neg_int: -4, neg_float: -1.5, array: [ 1, :two ], hash: { a: 1, "b" => 2 }, regexp: /ab+c/i, string: "s", symbol: :sym,
               words: %w[a b], call: Foo.bar(1), last: -4)
      end
    end
  RUBY
  SIGNATURE_EXPECTED = '(neg_int: -4, neg_float: -1.5, array: [ 1, :two ], hash: { a: 1, "b" => 2 }, regexp: /ab+c/i, string: "s", ' \
                       "symbol: :sym, words: %w[a b], call: Foo.bar(1), last: -4)"

  # The kinds of literal a default can be, including the mutable ones ([], {}, "") that worker briefs used to replace with a frozen constant.
  # (YARD 0.9.45 itself cannot parse a rational or imaginary default such as `2r`/`3i`: it raises in its method handler, so they are not here.)
  EVERY_LITERAL = [
    "nil", "true", "false", "0", "-4", "1_000", "-1.5", "1e3", ":sym", ":\"quoted sym\"", '""', '"s"', "'single'", '"a, b)"',
    "\"interp \#{1 + 1}\"", "[]", "{}", "[ 1, :two ]", "{ a: 1, \"b\" => 2 }", "[[1], [2]]", "{ a: { b: [] } }", "/ab+c/i", "%w[a b]", "%i[a b]",
    "1..2", "(1..)", "Foo", "Foo::BAR", "Foo.bar(1)", "foo(1, 2)", "->(x) { x }", "proc { |x| x }", "[ :a, :b ].freeze", "EMPTY"
  ].freeze

  def teardown = YARD::Registry.clear

  def test_signature_renders_every_default_literal_identically_on_every_ruby
    method = parse_method(SIGNATURE_SOURCE, "Sample#call")

    assert_equal SIGNATURE_EXPECTED, Signature.render(method.parameters)
  end

  # Frozen constants for keyword defaults (`class_names: EMPTY` instead of `class_names: []`) are not needed: the renderer gives the literal
  # back unchanged as a keyword, as a positional default, in the middle of the list and as the last parameter, on the Ruby running this suite.
  def test_every_literal_kind_renders_unchanged_through_real_yard_as_keyword_positional_middle_and_last
    EVERY_LITERAL.each do |literal|
      source = "class Sample\n  def call(first, pos = #{literal}, kw: #{literal}, mid: #{literal}, **attrs)\n  end\n  " \
               "def last_kw(kw: #{literal})\n  end\n  def last_pos(pos = #{literal})\n  end\nend\n"
      parsed = parse_method(source, "Sample#call")

      assert_equal "(first, pos = #{literal}, kw: #{literal}, mid: #{literal}, **attrs)", Signature.render(parsed.parameters), literal
      assert_equal "(kw: #{literal})", Signature.render(YARD::Registry.at("Sample#last_kw").parameters), "last keyword #{literal}"
      assert_equal "(pos = #{literal})", Signature.render(YARD::Registry.at("Sample#last_pos").parameters), "last positional #{literal}"
    end
  end

  def test_a_multi_line_default_is_joined_and_a_multi_line_string_is_kept_intact
    method = parse_method(<<~RUBY, "Sample#call")
      class Sample
        def call(hash: { a: 1,
                         b: [ 2,
                              3 ] }, text: "two
      lines", last: 1)
        end
      end
    RUBY

    assert_equal "(hash: { a: 1, b: [ 2, 3 ] }, text: \"two\nlines\", last: 1)", Signature.render(method.parameters)
  end

  def test_signature_strips_the_delimiters_each_ruby_leaves_on_a_default
    rendered = lambda do |default|
      Signature.render([ [ "width:", default ], [ "**attrs", nil ] ])
    end

    [ "-4", "-4,", "-4)", "-4,)", "-4 ,\n  " ].each { |raw| assert_equal "(width: -4, **attrs)", rendered.call(raw), raw.inspect }
    [ "[1, 2]", "[1, 2])", "[1, 2]," ].each { |raw| assert_equal "(width: [1, 2], **attrs)", rendered.call(raw), raw.inspect }
    assert_equal "(width: %w[a b], **attrs)", rendered.call("%w[a b])")
    assert_equal "(width: foo(1), **attrs)", rendered.call("foo(1))")
    assert_equal "(width: { a: 1, b: 2 }, **attrs)", rendered.call("{ a: 1,\n    b: 2 },")
    assert_equal "(value = -1)", Signature.render([ [ "value", "-1," ] ])
    [ "foo(1)", "Foo.bar(1)", '"a, b)"', "->(x) { x }", '""' ].each do |clean|
      assert_equal "(width: #{clean}, **attrs)", rendered.call(clean), clean.inspect
    end
    assert_equal '(width: "a, b)", **attrs)', rendered.call('"a, b)")')
    assert_equal "(width: ->(x) { x }, **attrs)", rendered.call("->(x) { x })")
    assert_equal "(a, b:)", Signature.render([ [ "a", nil ], [ "b:", nil ] ])
  end

  def test_a_multi_line_word_list_and_a_backslash_continuation_are_joined
    assert_equal "(words: %w[a b], **attrs)", Signature.render([ [ "words:", "%w[a\n          b]," ], [ "**attrs", nil ] ])
    assert_equal "(syms: %i[a b])", Signature.render([ [ "syms:", "%i[a\n  b])" ] ])
    assert_equal "(sum: 1 + 2)", Signature.render([ [ "sum:", "1 +\\\n  2)" ] ])
  end

  def test_signature_fails_loud_on_a_default_it_cannot_render
    [ ",", ")", "foo(", "<<~T", "<<~T\n  x\nT", "{ a: 1, # note\n b: 2 }" ].each do |raw|
      assert_raises(ArgumentError, raw.inspect) { Signature.render([ [ "width:", raw ] ]) }
    end
  end

  def test_the_error_names_the_method_and_the_parameter
    error = assert_raises(ArgumentError) { Signature.render([ [ "a", nil ], [ "width:", "foo(" ] ], owner: "Phlex::Shadcn::Button#initialize") }

    assert_includes error.message, "Phlex::Shadcn::Button#initialize"
    assert_includes error.message, '"width:"'
    assert_includes error.message, '"foo("'
  end

  def test_the_error_still_names_the_parameter_when_the_caller_gives_no_method
    error = assert_raises(ArgumentError) { Signature.list([ [ "value", ")" ] ]) }

    assert_includes error.message, '"value"'
    assert_includes error.message, "a method"
  end

  private

  # The YARD registry is process-wide state: parse into an empty one (teardown empties it again).
  def parse_method(source, path)
    YARD::Registry.clear
    YARD.parse_string(source)
    YARD::Registry.at(path)
  end
end

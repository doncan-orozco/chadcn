# frozen_string_literal: true

require "chadcn/test_case"

using Chadcn::Values::Refinements

# Refinements are invisible to respond_to?/send, so the refined predicates are called directly (no assert_predicate), and the
# custom failure message of `assert Values.blank_value?(value), value.inspect` is intended.
# rubocop:disable Minitest/AssertPredicate, Minitest/AssertWithExpectedArgument

class Chadcn::ValuesTest < Chadcn::TestCase
  Values = Chadcn::Values

  test "blank values are nil, false, empty or whitespace strings and empty collections" do
    [ nil, false, "", "  \n\t", [], {}, [].freeze ].each { |value| assert Values.blank_value?(value), value.inspect }
    [ true, 0, "a", " a ", [ nil ], { a: nil }, :sym, Object.new ].each { |value| refute Values.blank_value?(value), value.inspect }
  end

  test "blank_value?, filled? and unless_blank agree with Values.blank_value?" do
    assert "  ".blank_value?
    assert "x".filled?
    assert_nil "".unless_blank
    assert_equal "x", "x".unless_blank
    assert_nil nil.unless_blank
    assert_equal [ 1 ], [ 1 ].unless_blank
  end

  test "reject_blank drops blank elements and blank hash values" do
    assert_equal [ "a", 0, true ], [ "a", nil, "", false, 0, " ", [], true ].reject_blank
    assert_equal({ a: 1, c: "x" }, { a: 1, b: nil, c: "x", d: "", e: {} }.reject_blank)
  end

  test "merge_deep merges nested hashes, the argument wins, and does not mutate" do
    base = { data: { action: "a", slot: "x" }, class: "one", aria: { label: "l" } }
    other = { data: { action: "b" }, class: "two", aria: nil }
    merged = base.merge_deep(other)

    assert_equal({ data: { action: "b", slot: "x" }, class: "two", aria: nil }, merged)
    assert_equal({ data: { action: "a", slot: "x" }, class: "one", aria: { label: "l" } }, base)
    assert_equal({ a: 1 }, { a: { b: 1 } }.merge_deep({ a: 1 }))
    assert_equal({ a: { b: 1 } }, { a: 1 }.merge_deep({ a: { b: 1 } }))
  end

  test "snake_case converts the names the components use" do
    {
      "tabIndex" => "tab_index", "itemID" => "item_id", "httpEquiv" => "http_equiv", "DropdownMenu" => "dropdown_menu",
      "Chadcn::CheckItem" => "chadcn/check_item", "already_snake" => "already_snake", "kebab-case" => "kebab_case",
      "HTMLParser" => "html_parser", "className" => "class_name"
    }.each { |input, expected| assert_equal expected, input.snake_case, input }
  end

  test "unqualified keeps the last constant name" do
    assert_equal "Dialog", "Chadcn::Dialog".unqualified
    assert_equal "Dialog", "Dialog".unqualified
  end

  test "json escapes the characters that are unsafe in HTML" do
    unsafe = "<b> & x#{[ 0x2028 ].pack('U')}"
    backslash = "\\"
    expected = [ '{"a":"', backslash, "u003cb", backslash, "u003e ", backslash, "u0026 x", backslash, 'u2028"}' ].join

    assert_equal expected, Values.json({ a: unsafe })
    assert_equal '["a","b"]', Values.json(%w[a b])
    assert_equal '{"side":"top","avoid":true,"n":null}', Values.json({ side: "top", avoid: true, n: nil })
  end

  test "blank values also cover numbers, times and objects, and reject_blank reaches every enumerable" do
    [ 1, 0.0, Time.now, Struct.new(:a).new(1), :sym ].each { |value| refute Values.blank_value?(value), value.inspect }
    assert_equal [ 1, 2, 3 ], (1..3).reject_blank
    assert_equal [ "a" ], Set["a", nil, ""].reject_blank
    assert_equal [ 0, 1 ], [ 0, nil, 1, false ].each.reject_blank
    assert_nil false.unless_blank
    assert_equal 0, 0.unless_blank
  end

  test "the Hash refinement of reject_blank wins over the Enumerable one" do
    assert_equal({ a: "x" }, { a: "x", b: "" }.reject_blank)
  end

  test "json handles symbols, non-ASCII text and nested data" do
    assert_equal '{"side":"top","name":"café","n":[1,2.5,null]}', Values.json({ side: :top, name: "café", n: [ 1, 2.5, nil ] })
  end

  test "every library file that calls a helper opts in with using" do
    # The predicates end in "?", which a word boundary can never follow; the bare names still need \b.
    names = /\.(?:blank_value\?|filled\?|(?:unless_blank|reject_blank|merge_deep|snake_case|unqualified)\b)/
    library = File.expand_path("../../lib", __dir__)
    missing = Dir[File.join(library, "**/*.rb")].reject { |file| file.end_with?("chadcn/values.rb", "icons/catalog.rb") }.select do |file|
      code = File.readlines(file).reject { |line| line.lstrip.start_with?("#") }.join
      code.match?(names) && !code.include?("using Chadcn::Values::Refinements")
    end

    assert_empty missing, "these files call a Values helper without `using Chadcn::Values::Refinements`"
  end
end
# rubocop:enable Minitest/AssertPredicate, Minitest/AssertWithExpectedArgument

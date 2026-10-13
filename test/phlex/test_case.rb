# frozen_string_literal: true

require "test_helper"

module Phlex
  module Shadcn
    # Plain Minitest with the small `test "…" do` DSL and `assert_not_*` spellings the component tests are written in.
    class TestCase < Minitest::Test
      # Same naming as ActiveSupport's `test`: whitespace becomes `_`, punctuation stays, so names that differ only in punctuation
      # remain distinct. Unlike ActiveSupport, an empty name, a missing block or a duplicate name raises instead of overwriting.
      def self.test(name, &block)
        name = name.to_s
        raise ArgumentError, "test name cannot be empty" if name.strip.empty?
        raise ArgumentError, "test #{name.inspect} needs a block" unless block

        method_name = "test_#{name.gsub(/\s+/, '_')}"
        raise ArgumentError, "test #{name.inspect} is defined twice in #{self}" if method_defined?(method_name, false)

        define_method(method_name, &block)
      end

      def assert_not(*, **) = refute(*, **)
      def assert_not_includes(*) = refute_includes(*)
      def assert_not_nil(*) = refute_nil(*)
      def assert_not_equal(*) = refute_equal(*)
      def assert_not_predicate(*) = refute_predicate(*)
      def assert_not_empty(*) = refute_empty(*)
      def assert_not_match(*) = refute_match(*)
    end
  end
end

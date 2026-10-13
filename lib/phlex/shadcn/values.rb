# frozen_string_literal: true

require "json"

module Phlex
  module Shadcn
    # Small plain-Ruby helpers the components use, so the gem needs only Phlex and tailwind_merge. The Hash/Array/String/Object
    # helpers are refinements (nothing is patched globally): a component file opts in with
    # `using Phlex::Shadcn::Values::Refinements`. Their names are the gem's own, never the names of framework extensions.
    #
    # @api private
    module Values
      BLANK_STRING = /\A[[:space:]]*\z/
      # Replacement texts are the literal backslash-u sequences (double backslash), not the characters themselves.
      JSON_ESCAPES = { ">" => "\\u003e", "<" => "\\u003c", "&" => "\\u0026", [ 0x2028 ].pack("U") => "\\u2028", [ 0x2029 ].pack("U") => "\\u2029" }.freeze
      JSON_UNSAFE = Regexp.union(JSON_ESCAPES.keys).freeze

      # nil, false, empty or whitespace-only strings and empty collections are blank; everything else (0, true, objects) is not.
      def self.blank_value?(value)
        case value
        when nil, false then true
        when String then value.empty? || BLANK_STRING.match?(value)
        else value.respond_to?(:empty?) ? !!value.empty? : false
        end
      end

      # Recursive merge: nested hashes are merged, any other value of `other` wins. Returns a new hash.
      def self.merge_deep(hash, other)
        hash.merge(other) do |_key, this_value, other_value|
          this_value.is_a?(Hash) && other_value.is_a?(Hash) ? merge_deep(this_value, other_value) : other_value
        end
      end

      # `"DropdownMenu::CheckItem"` => `"dropdown_menu/check_item"`, `"tabIndex"` => `"tab_index"`.
      def self.snake_case(string)
        string.gsub("::", "/")
              .gsub(/([A-Z\d]+)([A-Z][a-z])/, '\1_\2')
              .gsub(/([a-z\d])([A-Z])/, '\1_\2')
              .tr("-", "_")
              .downcase
      end

      # `"Phlex::Shadcn::Dialog"` => `"Dialog"`.
      def self.unqualified(string) = string.to_s.split("::").last.to_s

      # JSON for a data attribute with the HTML-sensitive characters (& < > and the two JavaScript line separators) \u-escaped,
      # so the markup is safe to embed and byte-identical to what the components rendered before.
      def self.json(value) = JSON.generate(value).gsub(JSON_UNSAFE, JSON_ESCAPES)

      module Refinements
        refine Object do
          def blank_value? = Values.blank_value?(self)
          def filled? = !Values.blank_value?(self)
          def unless_blank = (self unless Values.blank_value?(self))
        end

        refine Enumerable do
          def reject_blank = reject { |element| Values.blank_value?(element) }
        end

        refine Hash do
          def reject_blank = reject { |_key, value| Values.blank_value?(value) }
          def merge_deep(other) = Values.merge_deep(self, other)
        end

        refine String do
          def snake_case = Values.snake_case(self)
          def unqualified = Values.unqualified(self)
        end
      end
    end
  end
end

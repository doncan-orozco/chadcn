# frozen_string_literal: true

require "ripper"

module Phlex
  module Shadcn
    class Llms
      # Renders a method's parameter list from YARD's `Method#parameters` pairs (`[name, default_source]`), identically on every Ruby.
      #
      # YARD hands back the default as a slice of the source text, and the slice is not clean: it can keep the delimiter that follows the
      # expression (`align_offset: -4` comes back as "-4," and, as the last parameter, "-4)"; `%w[a b]` as "%w[a b])" on newer Rubies), and
      # which delimiter survives depends on the Ruby that ran the parser. Printing it as is gave `align_offset: -4,,` and a snapshot that
      # differed between Ruby 3.2 and 3.3+. The fix is here, not in YARD: strip trailing delimiters until the text is a complete Ruby
      # expression, then put it on one line. A default that is already clean is never touched, so no author has to avoid literal defaults.
      module Signature
        TRAILING_DELIMITER = /[,)\s]\z/
        LINE_BREAK = /[ \t]*\r?\n[ \t]*/

        module_function

        # `(a, b: 1, **attrs)`
        def render(parameters) = "(#{list(parameters)})"

        # `a, b: 1, **attrs`
        def list(parameters) = parameters.map { |name, default| parameter(name, default) }.join(", ")

        # One parameter: `name`, `name = default` (positional) or `name: default` (keyword; YARD keeps the colon in the name).
        def parameter(name, default)
          return name if default.nil?

          name.end_with?(":") ? "#{name} #{default_source(default)}" : "#{name} = #{default_source(default)}"
        end

        # The default expression alone, on one line. Raises instead of printing a default that is not a complete Ruby expression, so a
        # YARD or Ruby change can never silently corrupt the snapshot.
        def default_source(source)
          text = source.to_s.strip
          text = text.chop.rstrip while text.match?(TRAILING_DELIMITER) && !complete?(text)
          line = text.gsub(LINE_BREAK, " ")
          return line if !line.empty? && complete?(line)

          raise ArgumentError, "cannot render the default #{source.inspect}: #{line.inspect} is not a complete Ruby expression"
        end

        def complete?(text) = !Ripper.sexp(text).nil?
        private_class_method :complete?
      end
    end
  end
end

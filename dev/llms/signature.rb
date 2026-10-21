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
      # expression, then join the lines the expression spans. A default that is already clean on one line is never touched, so no author
      # has to avoid literal defaults; line breaks inside a string literal are part of its value and are kept as they are.
      module Signature
        TRAILING_DELIMITER = /[,)\s]\z/
        WHITESPACE_TOKENS = %i[on_sp on_ignored_sp on_nl on_ignored_nl on_words_sep].freeze

        module_function

        # `(a, b: 1, **attrs)`. `owner` (for example "Button#initialize") only names the method in the error for a default that cannot be
        # rendered.
        def render(parameters, owner: nil) = "(#{list(parameters, owner: owner)})"

        # `a, b: 1, **attrs`
        def list(parameters, owner: nil) = parameters.map { |name, default| parameter(name, default, owner: owner) }.join(", ")

        # One parameter: `name`, `name = default` (positional) or `name: default` (keyword; YARD keeps the colon in the name).
        def parameter(name, default, owner: nil)
          return name if default.nil?

          source = default_source(default, "#{owner || "a method"} parameter #{name.inspect}")
          name.end_with?(":") ? "#{name} #{source}" : "#{name} = #{source}"
        end

        # The default expression alone, on one line (a string literal keeps its own line breaks). Raises instead of printing a default that
        # is not a complete Ruby expression, so a YARD or Ruby change can never silently corrupt the snapshot. `origin` names where the
        # default came from.
        def default_source(source, origin = "a parameter")
          text = source.to_s.strip
          text = text.chop.rstrip while text.match?(TRAILING_DELIMITER) && !complete?(text)
          line = join_lines(text)
          return line if line && !line.empty? && complete?(line)

          raise ArgumentError, "cannot render the default #{source.inspect} of #{origin}: #{(line || text).inspect} is not a complete Ruby expression"
        end

        # Replaces every run of whitespace tokens (the separators of a %w/%i literal included) that spans a line break with one space. Whitespace inside a string is not a whitespace
        # token, so it stays. A heredoc cannot be joined and is refused by the completeness check. Nil when a comment is in the way: joined lines would let it swallow the rest of the expression.
        def join_lines(text)
          tokens = Ripper.lex(text)
          return if tokens.any? { |token| token[1] == :on_comment }

          tokens.chunk_while { |a, b| WHITESPACE_TOKENS.include?(a[1]) && WHITESPACE_TOKENS.include?(b[1]) }.map do |run|
            run_text = run.sum("") { |token| token[2] }
            run.all? { |token| WHITESPACE_TOKENS.include?(token[1]) } && run_text.include?("\n") ? " " : run_text
          end.join
        end
        private_class_method :join_lines

        def complete?(text) = !Ripper.sexp(text).nil?
        private_class_method :complete?
      end
    end
  end
end

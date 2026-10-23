# frozen_string_literal: true

module Chadcn
  module Doctor
    module Checks
      # The managed block `rails g chadcn:install` writes. The block names no path outside the app: it imports the engine bundle, whose
      # entry file (engine.css) carries a self-relative `@source` for the gem's Ruby files (without it Tailwind generates none of the
      # component classes). A block an older generator wrote still carries its own `@source` line: harmless, but stale.
      #
      # @api private
      module SourceBlock
        NAME = "source block"

        # @param context [Context]
        # @return [Result]
        def self.call(context)
          return Result.failure(NAME, "#{context.css_name} not found", fix: "bin/rails tailwindcss:install, then #{context.install_command}") unless context.css_text

          block = context.managed_block
          return Result.failure(NAME, "no chadcn block in #{context.css_name}", fix: context.install_command) unless block
          unless context.imports_engine_bundle?
            return Result.failure(NAME, "the block does not import the engine bundle, which carries the @source for the gem's Ruby files",
                                  fix: context.install_command)
          end
          if context.block_sources.any?
            return Result.warning(NAME, "the block still carries an @source line from an older generator run (the engine bundle has its own)",
                                  fix: context.install_command)
          end

          Result.passed(NAME, "the engine bundle carries the @source for the gem's Ruby files")
        end
      end
    end
  end
end

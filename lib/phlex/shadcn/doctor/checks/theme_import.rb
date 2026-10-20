# frozen_string_literal: true

module Phlex
  module Shadcn
    module Doctor
      module Checks
        # The managed block imports the app's theme file (the one in the configured theme directory).
        #
        # @api private
        module ThemeImport
          NAME = "theme import"

          # @param context [Context]
          # @return [Result]
          def self.call(context)
            block = context.managed_block
            return Result.failure(NAME, "no phlex-shadcn block in #{context.css_name}", fix: context.install_command) unless block
            unless context.theme_dir
              return Result.failure(NAME, "no theme directory configured", fix: Context::THEME_DIR_FIX)
            end

            imported = context.block_imports
            return Result.passed(NAME, "the block imports #{context.theme_dir.join('theme.css')}") if imported.include?(context.theme_dir.join("theme"))

            Result.failure(NAME, "the block does not import #{context.theme_dir.join('theme.css')}", fix: context.install_command)
          end
        end
      end
    end
  end
end

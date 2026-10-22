# frozen_string_literal: true

module Chadcn
  module Doctor
    module Checks
      # The managed block `rails g chadcn:install` writes, with an `@source` line that points at the gem's Ruby files (without it
      # Tailwind generates none of the component classes).
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

          sources = context.block_sources
          return Result.failure(NAME, "the block has no @source line", fix: context.install_command) if sources.empty?
          return Result.passed(NAME, "@source points at the gem's lib") if sources.include?(context.gem_root.join("lib"))

          Result.warning(NAME, "@source does not point at #{context.gem_root.join('lib')} (the gem moved?)", fix: context.install_command)
        end
      end
    end
  end
end

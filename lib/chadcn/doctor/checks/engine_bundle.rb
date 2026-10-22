# frozen_string_literal: true

module Chadcn
  module Doctor
    module Checks
      # The engine's Tailwind bundle (`app/assets/builds/tailwind/chadcn`) imported by the managed block, and built.
      #
      # @api private
      module EngineBundle
        NAME = "engine bundle"
        BUNDLE = "app/assets/builds/tailwind/chadcn" # gem_check:allow GEM_ESCAPES_ROOT -- the doctor checks the host engine bundle

        # @param context [Context]
        # @return [Result]
        def self.call(context)
          block = context.managed_block
          return Result.failure(NAME, "no chadcn block in #{context.css_name}", fix: context.install_command) unless block

          target = context.path(BUNDLE)
          imported = context.block_imports.map(&:to_s)
          return Result.failure(NAME, "the block does not import #{BUNDLE}", fix: context.install_command) unless imported.include?(target.to_s)
          return Result.passed(NAME, "#{BUNDLE} is imported and built") if target.sub_ext(".css").file?

          Result.warning(NAME, "#{BUNDLE}.css is not built yet", fix: "bin/rails tailwindcss:build")
        end
      end
    end
  end
end

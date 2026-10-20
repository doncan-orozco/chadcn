# frozen_string_literal: true

module Phlex
  module Shadcn
    module Doctor
      module Checks
        # The JavaScript pipeline: importmap-rails, which gets the gem's pins from its engine. Other pipelines are reported, not
        # configured (see the js-bundlers decision when it lands).
        #
        # @api private
        module JsPipeline
          NAME = "javascript pipeline"

          # @param context [Context]
          # @return [Result]
          def self.call(context)
            if context.path("config/importmap.rb").file? && context.gem_version("importmap-rails")
              Result.passed(NAME, "importmap-rails #{context.gem_version('importmap-rails')}: the gem's controllers and primitives are pinned by its engine")
            elsif context.path("config/importmap.rb").file?
              Result.failure(NAME, "config/importmap.rb exists but importmap-rails is not in the bundle", fix: "bundle add importmap-rails")
            elsif context.path("package.json").file?
              Result.warning(NAME, "package.json without importmap-rails: the gem's JavaScript is not wired automatically",
                             fix: "use importmap-rails (bin/rails importmap:install) until bundler support lands")
            else
              Result.failure(NAME, "no JavaScript pipeline found (config/importmap.rb)", fix: "bin/rails importmap:install")
            end
          end
        end
      end
    end
  end
end

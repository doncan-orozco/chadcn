# frozen_string_literal: true

module Phlex
  module Shadcn
    module Doctor
      module Checks
        # The JavaScript pipeline and how the gem's JavaScript reaches it (dev/decisions/js-bundlers.md): importmap-rails gets the gem's
        # pins from its engine; an esbuild (jsbundling-rails) app gets managed copies from `rails g phlex:shadcn:install`, which this
        # check compares with what the generator would write. Other pipelines are reported, not configured.
        #
        # @api private
        module JsPipeline
          NAME = "javascript pipeline"

          # @param context [Context]
          # @return [Result]
          def self.call(context)
            case JsBundle.pipeline(context.root, context.gems)
            when :importmap then importmap(context)
            when :esbuild then esbuild(context)
            else unknown(context)
            end
          end

          # @param context [Context]
          # @return [Result]
          def self.importmap(context)
            version = context.gem_version("importmap-rails")
            return Result.passed(NAME, "importmap-rails #{version}: the gem's controllers and primitives are pinned by its engine") if version

            Result.failure(NAME, "config/importmap.rb exists but importmap-rails is not in the bundle", fix: "bundle add importmap-rails")
          end
          private_class_method :importmap

          # @param context [Context]
          # @return [Result]
          def self.esbuild(context)
            problems = missing_copies(context) + missing_wiring(context)
            if problems.empty?
              return Result.passed(NAME, "esbuild (jsbundling): the gem's controllers and primitives are copied, registered and up to date")
            end

            more = problems.size > 3 ? " (+#{problems.size - 3} more)" : nil
            Result.failure(NAME, "esbuild (jsbundling): #{problems.first(3).join('; ')}#{more}", fix: "#{context.install_command} --js esbuild")
          end
          private_class_method :esbuild

          # @return [Array<String>] the copied files that are missing or differ from what the generator writes
          def self.missing_copies(context)
            files = JsBundle.files(context.gem_root)
            absent = files.keys.reject { |path| context.path(path).file? }
            stale = (files.keys - absent).reject { |path| context.read(context.path(path)) == files.fetch(path) }
            problems = []
            problems << "#{absent.size} copied file(s) missing (#{absent.first})" if absent.any?
            problems << "#{stale.size} copied file(s) differ from the gem's (#{stale.first}): the gem was updated" if stale.any?
            problems
          end
          private_class_method :missing_copies

          # @return [Array<String>] what else the bundler needs: the entry import and the floating-ui package
          def self.missing_wiring(context)
            problems = []
            entry = context.read(context.path(JsBundle::ENTRY))
            problems << %(#{JsBundle::ENTRY} lacks #{JsBundle::APPLICATION_IMPORT}) unless entry&.match?(JsBundle::APPLICATION_IMPORT_PATTERN)
            problems << "#{JsBundle::FLOATING_UI} is not in package.json" unless JsBundle.floating_ui?(context.read(context.path("package.json")))
            problems
          end
          private_class_method :missing_wiring

          # @param context [Context]
          # @return [Result]
          def self.unknown(context)
            if context.path("package.json").file?
              Result.warning(NAME, "package.json without importmap-rails or jsbundling with esbuild: the gem's JavaScript is not wired",
                             fix: "use importmap-rails (bin/rails importmap:install) or esbuild (bin/rails javascript:install:esbuild)")
            else
              Result.failure(NAME, "no JavaScript pipeline found (config/importmap.rb or package.json)",
                             fix: "bin/rails importmap:install, or bin/rails javascript:install:esbuild")
            end
          end
          private_class_method :unknown
        end
      end
    end
  end
end

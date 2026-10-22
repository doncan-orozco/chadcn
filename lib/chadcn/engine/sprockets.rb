# frozen_string_literal: true

module Chadcn
  # Reopened (the superclass is declared in engine.rb, which requires this file from its class body; Zeitwerk ignores engine/).
  class Engine
    # Sprockets support (dev/decisions/sprockets.md). Sprockets 4 refuses to serve or link an asset that is not declared precompiled
    # (`AssetNotPrecompiledError`), and an app's own app/assets/config/manifest.js cannot name files inside an installed gem, so the
    # importmap pins of the gem's controllers, primitives and vendored floating-ui files only resolve when the engine declares those
    # logical paths itself. Propshaft serves every file of its load path and ignores the precompile list, so the engine only calls this
    # when Sprockets is loaded.
    #
    # @api private
    module SprocketsAssets
      # The files that importmap pins point at.
      PATTERN = "**/*.js"

      # @param directories [Array<#to_s>] asset roots of the gem (app/javascript, vendor/javascript)
      # @return [Array<String>] the logical paths of their JavaScript files, relative to each root, sorted
      def self.logical_paths(directories)
        directories.flat_map do |directory|
          Dir.glob(PATTERN, base: directory.to_s)
        end.sort.uniq
      end

      # Adds the gem's JavaScript to the precompile list of a Sprockets app, once.
      #
      # @param assets [#precompile] `app.config.assets`; a list without sprockets-rails' options object is left alone
      # @param directories [Array<#to_s>] asset roots of the gem
      # @return [Symbol] +:skipped+ (no precompile list) or +:declared+
      def self.install(assets, directories:)
        precompile = assets.respond_to?(:precompile) ? assets.precompile : nil
        return :skipped unless precompile

        precompile.concat(logical_paths(directories) - precompile)
        :declared
      end
    end
  end
end

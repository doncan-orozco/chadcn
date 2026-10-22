# frozen_string_literal: true

require "generators/chadcn/install/sprockets_manifest"

module Chadcn
  module Doctor
    module Checks
      # Names the asset pipeline the app serves its assets with (dev/decisions/sprockets.md): Propshaft (the default of current
      # releases) or Sprockets (sprockets-rails). The Propshaft-only stub filter is judged by the `propshaft stub filter` check; here a
      # Sprockets app is checked for the one thing it needs from the app: a manifest that links the Tailwind build, because Sprockets
      # refuses to serve an asset that is not declared. The gem declares its own JavaScript (engine/sprockets.rb).
      #
      # @api private
      module AssetPipeline
        NAME = "asset pipeline"
        Manifest = Generators::SprocketsManifest
        SPROCKETS_MIN = Gem::Version.new("4")
        private_constant :Manifest, :SPROCKETS_MIN

        # @param context [Context]
        # @return [Result]
        def self.call(context)
          propshaft = context.gem_version("propshaft")
          sprockets_rails = context.gem_version("sprockets-rails")
          return both_result(propshaft, sprockets_rails) if propshaft && sprockets_rails
          return Result.passed(NAME, "Propshaft #{propshaft}") if propshaft
          return sprockets_result(context, sprockets_rails) if sprockets_rails

          Result.warning(NAME, "neither Propshaft nor Sprockets (sprockets-rails) is in the bundle: the gem's assets have no pipeline to serve them",
                         fix: "bundle add propshaft (the current default), or sprockets-rails")
        end

        # @return [Result]
        def self.both_result(propshaft, sprockets)
          Result.warning(NAME, "Propshaft #{propshaft} and Sprockets (sprockets-rails #{sprockets}) are both in the bundle",
                         fix: "keep one asset pipeline: remove propshaft or sprockets-rails from the Gemfile")
        end
        private_class_method :both_result

        # @param context [Context]
        # @param version [Gem::Version] sprockets-rails
        # @return [Result]
        def self.sprockets_result(context, version)
          sprockets = context.gem_version("sprockets")
          name = [ "Sprockets", sprockets, "(sprockets-rails #{version})" ].compact.join(" ")
          if sprockets && sprockets < SPROCKETS_MIN
            return Result.warning(NAME, "#{name}: Sprockets below 4 is not supported", fix: "bundle update sprockets (chadcn needs Sprockets 4)")
          end

          manifest = context.read(context.path(Manifest::PATH))
          unless manifest
            return Result.warning(NAME, "#{name}: #{Manifest::PATH} not found", fix: "create #{Manifest::PATH} with `//= link_tree ../builds`")
          end

          if Manifest.links_builds?(manifest)
            return Result.passed(NAME, "#{name}: the manifest links the Tailwind build; the gem declares its JavaScript itself")
          end

          Result.warning(NAME, "#{name}: #{Manifest::PATH} does not link #{Manifest::BUILDS_DIR} (tailwind.css is refused at render time)",
                         fix: "add `//= link_tree ../builds` to #{Manifest::PATH}")
        end
        private_class_method :sprockets_result
      end
    end
  end
end

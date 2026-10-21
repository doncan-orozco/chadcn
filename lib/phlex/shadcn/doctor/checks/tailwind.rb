# frozen_string_literal: true

module Phlex
  module Shadcn
    module Doctor
      module Checks
        # Tailwind 4 through tailwindcss-rails, and an entry file written for Tailwind 4 (`@import "tailwindcss";`).
        #
        # @api private
        module Tailwind
          NAME = "tailwind"
          MINIMUM = Gem::Version.new("4")
          # The first tailwindcss-rails with `tailwindcss:engines` (Tailwindcss::Engines.bundle), the task that bundles an engine's
          # app/assets/tailwind/<engine>/engine.css, which is how the gem's CSS reaches the host. Verified in the tailwindcss-rails
          # sources: v4.2.3 has no lib/tailwindcss/engines.rb and no `engines` task in lib/tasks/build.rake, v4.3.0 (2025-07-06, "Experimental
          # support for engines") has both. No minimum exists for tailwindcss-ruby (the Tailwind CLI): the engine CSS is plain
          # Tailwind 4 `@import`/`@source`/`@theme` syntax, so the Tailwind 4 check below is all it needs.
          # (A 4.3.0 prerelease sorts below 4.3.0 and fails: intended, the released task is what was verified.)
          MINIMUM_ENGINE_SUPPORT = Gem::Version.new("4.3.0")

          # The fix hint for every tailwindcss-rails below the minimum (3.x and 4.x alike).
          # @return [String]
          def self.update_hint = "bundle update tailwindcss-rails (#{MINIMUM_ENGINE_SUPPORT} or newer)"
          private_class_method :update_hint

          # @param context [Context]
          # @return [Result]
          def self.call(context)
            tailwind_rails = context.gem_version("tailwindcss-rails")
            return Result.failure(NAME, "tailwindcss-rails is not in the bundle", fix: "bundle add tailwindcss-rails && bin/rails tailwindcss:install") unless tailwind_rails

            if tailwind_rails < MINIMUM
              return Result.failure(NAME, "tailwindcss-rails #{tailwind_rails} found, the engine bundle needs tailwindcss-rails 4",
                                    fix: "#{update_hint} and move the entry file to @import \"tailwindcss\";")
            end

            if tailwind_rails < MINIMUM_ENGINE_SUPPORT
              return Result.failure(NAME, "tailwindcss-rails #{tailwind_rails} found, it cannot bundle an engine's CSS before #{MINIMUM_ENGINE_SUPPORT}",
                                    fix: "#{update_hint}, then bin/rails tailwindcss:build")
            end

            version = context.gem_version("tailwindcss-ruby") || tailwind_rails
            if version < MINIMUM
              return Result.failure(NAME, "Tailwind #{version} found, the components need Tailwind 4",
                                    fix: "#{update_hint} and move the entry file to @import \"tailwindcss\";")
            end

            css = context.css_text
            return Result.failure(NAME, "#{context.css_name} not found", fix: "bin/rails tailwindcss:install") unless css
            unless css.match?(/^@import\s+["']tailwindcss["']/)
              return Result.failure(NAME, %(#{context.css_name} has no @import "tailwindcss"), fix: %(start #{context.css_name} with @import "tailwindcss";))
            end

            Result.passed(NAME, "tailwindcss-rails #{tailwind_rails}, Tailwind #{version}")
          end
        end
      end
    end
  end
end

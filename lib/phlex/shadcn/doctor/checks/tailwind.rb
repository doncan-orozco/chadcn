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

          # @param context [Context]
          # @return [Result]
          def self.call(context)
            tailwind_rails = context.gem_version("tailwindcss-rails")
            return Result.failure(NAME, "tailwindcss-rails is not in the bundle", fix: "bundle add tailwindcss-rails && bin/rails tailwindcss:install") unless tailwind_rails

            if tailwind_rails < MINIMUM
              return Result.failure(NAME, "tailwindcss-rails #{tailwind_rails} found, the engine bundle needs tailwindcss-rails 4",
                                    fix: "bundle update tailwindcss-rails (4.x) and move the entry file to @import \"tailwindcss\";")
            end

            version = context.gem_version("tailwindcss-ruby") || tailwind_rails
            if version < MINIMUM
              return Result.failure(NAME, "Tailwind #{version} found, the components need Tailwind 4",
                                    fix: "bundle update tailwindcss-rails (4.x) and move the entry file to @import \"tailwindcss\";")
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

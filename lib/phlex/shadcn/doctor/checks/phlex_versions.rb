# frozen_string_literal: true

module Phlex
  module Shadcn
    module Doctor
      module Checks
        # phlex is in the range the gem supports, and phlex-rails (when present) is the same major version.
        #
        # @api private
        module PhlexVersions
          NAME = "phlex versions"

          # @param context [Context]
          # @return [Result]
          def self.call(context)
            phlex = context.gem_version("phlex")
            return Result.failure(NAME, "phlex is not in the bundle", fix: "bundle add phlex") unless phlex

            requirement = context.phlex_requirement
            unless requirement.satisfied_by?(phlex)
              return Result.failure(NAME, "phlex #{phlex} is outside the supported range (#{requirement})", fix: "bundle update phlex (#{requirement})")
            end

            phlex_rails = context.gem_version("phlex-rails")
            return Result.passed(NAME, "phlex #{phlex} (#{requirement}), no phlex-rails") unless phlex_rails
            return Result.passed(NAME, "phlex #{phlex} (#{requirement}), phlex-rails #{phlex_rails}") if phlex_rails.segments.first == phlex.segments.first

            Result.failure(NAME, "phlex-rails #{phlex_rails} does not match phlex #{phlex}", fix: "bundle update phlex phlex-rails")
          end
        end
      end
    end
  end
end

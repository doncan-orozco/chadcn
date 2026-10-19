# frozen_string_literal: true

module Phlex
  module Shadcn
    # Reopened (the superclass is declared in engine.rb, which requires this file from its class body; Zeitwerk ignores engine/).
    class Engine
      # Hides the stubs tailwindcss-rails writes to <app>/app/assets/builds/tailwind/ (one per engine, each an absolute `@import`
      # only the Tailwind CLI resolves) from the assets Propshaft serves, so `stylesheet_link_tag :app` does not link them: the
      # browser would 404 on the import and the stub would disclose the gem's filesystem path.
      #
      # Recorded exception to ruby-gem-conventions R4 (no monkey patches of framework classes): Propshaft only excludes whole load-path
      # roots and the stubs sit in the host's own app/assets/builds next to the compiled CSS, so there is no public seam. {.install}
      # prepends a filter to Propshaft::LoadPath over its private file filter (`without_dotfiles`, Propshaft 1.2 and 1.3), only
      # when that hook exists with the expected arity, and `config.phlex_shadcn.hide_tailwind_stubs = false` turns it off. Remove
      # once tailwindcss-rails stops writing stubs inside an asset root.
      #
      # The module itself holds no state: each installed target gets its own filter module (the stubs prefix lives in a closure),
      # which includes this module so the target's ancestors name the exception.
      #
      # @api private
      module TailwindStubFilter
        # The private Propshaft::LoadPath method the filter wraps.
        HOOK = :without_dotfiles

        class << self
          # Prepends the filter to +target+ (Propshaft::LoadPath) when enabled and the private one-argument hook is there.
          # Installing twice prepends once.
          #
          # @param target [Class] the load path class to hook
          # @param stubs_dir [Pathname, String] the directory whose files are hidden (the app's app/assets/builds/tailwind)
          # @param enabled [Boolean] `config.phlex_shadcn.hide_tailwind_stubs`
          # @param logger [Logger] receives one warning when the hook is missing or has another signature
          # @return [Symbol] +:disabled+, +:installed+ or +:unsupported+ (warning logged, nothing prepended)
          def install(target, stubs_dir:, enabled:, logger:)
            return :disabled unless enabled
            return :installed if target.include?(self)

            unless hook?(target)
              logger.warn(
                "[phlex-shadcn] #{target}##{HOOK}(files) not found (propshaft #{Gem.loaded_specs['propshaft']&.version}): the " \
                "tailwindcss-rails stubs in #{stubs_dir}/ stay linked by `stylesheet_link_tag :app` (browser 404). Link \"tailwind\" " \
                "explicitly, or set config.phlex_shadcn.hide_tailwind_stubs = false to silence this warning."
              )
              return :unsupported
            end

            target.prepend(filter_for("#{stubs_dir}/"))
            :installed
          end

          private

          def hook?(target) = target.private_method_defined?(HOOK) && target.instance_method(HOOK).arity == 1

          # One module per target: the prefix is captured here, so two targets (or a test double) never share state.
          def filter_for(stubs)
            marker = self
            Module.new do
              include marker

              private

              define_method(HOOK) { |files| super(files).reject { |file| file.to_s.start_with?(stubs) } }
            end
          end
        end
      end
    end
  end
end

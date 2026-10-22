# frozen_string_literal: true

module Chadcn
  module Doctor
    module Checks
      # With Propshaft and tailwindcss-rails, the gem hides the Tailwind stubs from the served assets unless the app turned that off.
      # The filter only installs when Propshaft has the private hook it wraps (1.2 and 1.3), so an enabled setting is not enough: the
      # check asks the context whether the hook is there, as the filter itself does.
      #
      # @api private
      module PropshaftStubFilter
        NAME = "propshaft stub filter"

        # @param context [Context]
        # @return [Result]
        def self.call(context)
          unless context.gem_version("propshaft") && context.gem_version("tailwindcss-rails")
            return Result.passed(NAME, "not applicable (needs Propshaft and tailwindcss-rails)")
          end
          unless context.hide_tailwind_stubs?
            return Result.warning(NAME, "config.chadcn.hide_tailwind_stubs is false: stylesheet_link_tag :app links stubs that 404",
                                  fix: "remove config.chadcn.hide_tailwind_stubs = false, or exclude app/assets/builds/tailwind yourself")
          end
          return Result.passed(NAME, "the Tailwind stubs are hidden from the served assets") if context.propshaft_hook?

          Result.warning(NAME, "propshaft #{context.gem_version('propshaft')} has no one-argument LoadPath#without_dotfiles: the stub filter " \
                               "is not installed and the stubs stay linked (404)",
                         fix: %(bundle update propshaft (1.2 or 1.3), or link "tailwind" explicitly in the layout instead of :app))
        end
      end
    end
  end
end

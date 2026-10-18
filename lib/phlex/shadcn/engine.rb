# frozen_string_literal: true

require "rails/engine"

module Phlex
  module Shadcn
    # Rails integration, loaded only when Rails::Engine is defined (see lib/phlex/shadcn.rb); the plain-Phlex path never touches it.
    # It is required when the gem loads, so rails/engine has to be loaded before the gem (config/application.rb does that before
    # Bundler.require).
    #
    # A host that installs the gem gets, without copying any file:
    #   - the importmap pins for the Stimulus controllers (`controllers/shadcn/*`), the shared primitives (`shadcn/primitives/*`) and the
    #     vendored floating-ui files, so the host's `eagerLoadControllersFrom("controllers")` registers the `shadcn--*` controllers;
    #   - the gem's JavaScript and vendor directories on the asset load path (and watched by importmap's development cache sweeper);
    #   - the theme tooling (`Phlex::Shadcn::Theme`, rake tasks `phlex_shadcn:theme:*`) pointed at the host's theme directory
    #     (`Phlex::Shadcn.config.theme_dir`, set from `config.phlex_shadcn.theme_dir`);
    #   - the Tailwind entry point in app/assets/tailwind/phlex-shadcn/engine.css, bundled by tailwindcss-rails, which
    #     `rails g phlex:shadcn:install` imports together with the `@source` line for the gem's Ruby files.
    #
    # Configuration (config/application.rb):
    #   config.phlex_shadcn.theme_dir = "app/assets/tailwind/theme"   # where theme.css and presets/ live; relative to the app root
    #   config.phlex_shadcn.theme_task_aliases = true                 # false when the app defines its own theme:* tasks
    #
    # `theme_dir` wins over a value already set with Phlex::Shadcn.configure, which wins over the default.
    #
    # @api private
    class Engine < ::Rails::Engine
      # tailwindcss-rails looks for app/assets/tailwind/<engine_name>/engine.css.
      engine_name "phlex-shadcn"

      # Where theme.css and presets/ live in the app (the default of `config.phlex_shadcn.theme_dir`).
      DEFAULT_THEME_DIR = "app/assets/tailwind/theme"
      JAVASCRIPT_DIRECTORIES = %w[app/javascript vendor/javascript].freeze
      private_constant :JAVASCRIPT_DIRECTORIES

      # Prepended to Propshaft::LoadPath: drops the stubs tailwindcss-rails writes to <app>/app/assets/builds/tailwind/ (one per engine, each an
      # absolute `@import` only the Tailwind CLI resolves) from the served assets. Deliberate exception to ruby-gem-conventions R4: Propshaft
      # only excludes load-path roots (railtie `paths.without(excluded_paths)`) and tailwindcss-rails hardcodes the stub location
      # (Tailwindcss::Engines.bundle), so there is no public seam. Hooks the private file filter of Propshaft 1.2-1.3; when a release drops
      # it the initializer logs a warning instead of failing silently. Remove once upstream stops writing stubs inside an asset root.
      module TailwindStubFilter
        STUB_DIR = "app/assets/builds/tailwind"

        private

        def without_dotfiles(files)
          stubs = "#{::Rails.root.join(STUB_DIR)}/"
          super.reject { |file| file.to_s.start_with?(stubs) }
        end
      end
      private_constant :TailwindStubFilter

      config.phlex_shadcn = ActiveSupport::OrderedOptions.new
      config.phlex_shadcn.theme_dir = nil
      # Short `theme:list|use|import|check` aliases of the phlex_shadcn:theme:* tasks. Turn them off while the app defines its own
      # `theme:*` tasks (Rake would run both bodies). Read when the tasks load, so set it in config/application.rb.
      config.phlex_shadcn.theme_task_aliases = true

      initializer "phlex_shadcn.assets" do |app|
        if app.config.respond_to?(:assets)
          JAVASCRIPT_DIRECTORIES.map { |dir| root.join(dir).to_s }.each do |path|
            app.config.assets.paths << path unless app.config.assets.paths.map(&:to_s).include?(path)
          end
        end
      end

      initializer "phlex_shadcn.importmap", before: "importmap" do |app|
        if app.config.respond_to?(:importmap)
          app.config.importmap.paths << root.join("config/importmap.rb")
          app.config.importmap.cache_sweepers.concat(JAVASCRIPT_DIRECTORIES.map { |dir| root.join(dir) })
        end
      end

      # The engine's Tailwind entry (app/assets/tailwind/phlex-shadcn) is input of the Tailwind CLI, not a browser stylesheet, so
      # Propshaft must not serve it. tailwindcss-rails excludes the app's own app/assets/tailwind for the same reason. (Propshaft only
      # excludes load-path roots: the stub tailwindcss-rails writes to app/assets/builds/tailwind/ is served like for any engine.)
      initializer "phlex_shadcn.exclude_tailwind_inputs", before: "propshaft.append_assets_path" do |app|
        if app.config.respond_to?(:assets) && app.config.assets.respond_to?(:excluded_paths)
          path = root.join("app/assets/tailwind")
          app.config.assets.excluded_paths << path unless app.config.assets.excluded_paths.map(&:to_s).include?(path.to_s)
        end
      end

      initializer "phlex_shadcn.hide_tailwind_stubs" do |app|
        next unless defined?(::Propshaft::LoadPath) && app.config.respond_to?(:assets)
        next if ::Propshaft::LoadPath.include?(TailwindStubFilter)

        if ::Propshaft::LoadPath.private_method_defined?(:without_dotfiles)
          ::Propshaft::LoadPath.prepend(TailwindStubFilter)
        else
          ::Rails.logger.warn(
            "[phlex-shadcn] Propshaft #{Gem.loaded_specs['propshaft']&.version} has no LoadPath#without_dotfiles: the tailwindcss-rails " \
            "stubs in #{TailwindStubFilter::STUB_DIR}/ stay linked by `stylesheet_link_tag :app` (browser 404). Link \"tailwind\" explicitly."
          )
        end
      end

      # Precedence: config.phlex_shadcn.theme_dir, then a value already set with Phlex::Shadcn.configure, then the default.
      initializer "phlex_shadcn.theme" do |app|
        configured = app.config.phlex_shadcn.theme_dir
        next if configured.nil? && Phlex::Shadcn.config.theme_dir

        # Pathname#join keeps an absolute value and roots a relative one at the app, whatever the working directory is.
        theme_dir = app.root.join(configured || DEFAULT_THEME_DIR).to_s
        Phlex::Shadcn.configure { |config| config.theme_dir = theme_dir }
      end
    end
  end
end

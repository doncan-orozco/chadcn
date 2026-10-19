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
    #   config.phlex_shadcn.hide_tailwind_stubs = true                # false to leave the tailwindcss-rails stubs to Propshaft
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
      # Where tailwindcss-rails writes one stub per engine, inside the app's own builds root (Tailwindcss::Engines.bundle).
      TAILWIND_STUBS_DIR = "app/assets/builds/tailwind"
      private_constant :JAVASCRIPT_DIRECTORIES, :TAILWIND_STUBS_DIR

      # The recorded ruby-gem-conventions R4 exception (see engine/tailwind_stub_filter.rb); required here, never autoloaded.
      require_relative "engine/tailwind_stub_filter"
      private_constant :TailwindStubFilter

      config.phlex_shadcn = ActiveSupport::OrderedOptions.new
      config.phlex_shadcn.theme_dir = nil
      # Short `theme:list|use|import|check` aliases of the phlex_shadcn:theme:* tasks. Turn them off while the app defines its own
      # `theme:*` tasks (Rake would run both bodies). Read when the tasks load, so set it in config/application.rb.
      config.phlex_shadcn.theme_task_aliases = true
      # Hide the stubs tailwindcss-rails writes to app/assets/builds/tailwind/ from the served assets (TailwindStubFilter). Set it
      # to false to serve them yourself or to keep Propshaft untouched; the stubs then stay linked by `stylesheet_link_tag :app`.
      # Read by an engine initializer, so set it in config/application.rb (like theme_task_aliases).
      config.phlex_shadcn.hide_tailwind_stubs = true

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
      # excludes load-path roots; the stub tailwindcss-rails writes to app/assets/builds/tailwind/ is hidden by TailwindStubFilter below.)
      initializer "phlex_shadcn.exclude_tailwind_inputs", before: "propshaft.append_assets_path" do |app|
        if app.config.respond_to?(:assets) && app.config.assets.respond_to?(:excluded_paths)
          path = root.join("app/assets/tailwind")
          app.config.assets.excluded_paths << path unless app.config.assets.excluded_paths.map(&:to_s).include?(path.to_s)
        end
      end

      # Only where tailwindcss-rails writes stubs; a host without it (or without Propshaft) gets neither the hook nor a warning.
      initializer "phlex_shadcn.hide_tailwind_stubs" do |app|
        next unless defined?(::Tailwindcss) && defined?(::Propshaft::LoadPath) && app.config.respond_to?(:assets)

        TailwindStubFilter.install(
          ::Propshaft::LoadPath,
          stubs_dir: app.root.join(TAILWIND_STUBS_DIR),
          enabled: app.config.phlex_shadcn.hide_tailwind_stubs,
          logger: ::Rails.logger
        )
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

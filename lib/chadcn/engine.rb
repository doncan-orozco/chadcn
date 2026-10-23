# frozen_string_literal: true

require "rails/engine"

module Chadcn
  # Rails integration, loaded only when Rails::Engine is defined (see lib/chadcn.rb); the plain-Phlex path never touches it.
  # It is required when the gem loads, so rails/engine has to be loaded before the gem (config/application.rb does that before
  # Bundler.require).
  #
  # A host that installs the gem gets, without copying any file:
  #   - the importmap pins for the Stimulus controllers (`controllers/chadcn/*`), the shared primitives (`chadcn/primitives/*`) and the
  #     vendored floating-ui files, so the host's `eagerLoadControllersFrom("controllers")` registers the `chadcn--*` controllers;
  #   - the gem's JavaScript and vendor directories on the asset load path (and watched by importmap's development cache sweeper);
  #   - the theme tooling (`Chadcn::Theme`, rake tasks `chadcn:theme:*`) pointed at the host's theme directory
  #     (`Chadcn.config.theme_dir`, set from `config.chadcn.theme_dir`);
  #   - the Tailwind entry point in app/assets/tailwind/chadcn/engine.css, bundled by tailwindcss-rails, which
  #     `rails g chadcn:install` imports together with the `@source` line for the gem's Ruby files;
  #   - generated ids (`dialog-1`, `dropdown-menu-2-trigger`) numbered per request instead of per render (`Chadcn::Sequence`), so a
  #     layout, its view and the Turbo frames of one response never repeat an id.
  #
  # Configuration (config/application.rb):
  #   config.chadcn.theme_dir = "app/assets/tailwind/theme"   # where theme.css and presets/ live; relative to the app root
  #   config.chadcn.theme_task_aliases = true                 # false when the app defines its own theme:* tasks
  #   config.chadcn.hide_tailwind_stubs = true                # false to leave the tailwindcss-rails stubs to Propshaft
  #   config.chadcn.override_dir = "app/components/chadcn"    # where ejected components live (`rails g chadcn:eject`)
  #
  # `override_dir` is read while the app boots, before its autoload paths exist: set it in config/application.rb or
  # config/environments/*.rb (config/initializers/*.rb raise). Ejecting a component needs a restart; editing an ejected file reloads.
  #
  # `theme_dir` wins over a value already set with Chadcn.configure, which wins over the default.
  #
  # @api private
  class Engine < ::Rails::Engine
    # tailwindcss-rails looks for app/assets/tailwind/<engine_name>/engine.css.
    engine_name "chadcn"

    # Where theme.css and presets/ live in the app (the default of `config.chadcn.theme_dir`).
    DEFAULT_THEME_DIR = "app/assets/tailwind/theme"
    # Where ejected components live by default (the default of `config.chadcn.override_dir`).
    DEFAULT_OVERRIDE_DIR = "app/components/chadcn"
    JAVASCRIPT_DIRECTORIES = %w[app/javascript vendor/javascript].freeze
    # Where tailwindcss-rails writes one stub per engine, inside the app's own builds root (Tailwindcss::Engines.bundle).
    TAILWIND_STUBS_DIR = "app/assets/builds/tailwind"
    private_constant :JAVASCRIPT_DIRECTORIES, :TAILWIND_STUBS_DIR

    # The recorded ruby-gem-conventions R4 exception (see engine/tailwind_stub_filter.rb); required here, never autoloaded.
    require_relative "engine/tailwind_stub_filter"
    private_constant :TailwindStubFilter

    # Declares the gem's JavaScript precompiled in Sprockets apps (dev/decisions/sprockets.md).
    require_relative "engine/sprockets"
    private_constant :SprocketsAssets

    # The counters behind the generated ids for the current request (Chadcn::Sequence): an ActiveSupport::CurrentAttributes, so one
    # instance per thread, reset by the Rails executor before and after every request and job. Installed as
    # `Chadcn.config.sequence_store` below, so a layout, its view and the Turbo frames of one response number the roots in one
    # sequence and the next request starts again from 1. Outside the executor (a rake task, a script) the counters keep growing
    # for the thread, which never repeats an id either.
    class RequestSequences < ActiveSupport::CurrentAttributes
      attribute :counters

      # @return [Hash{Symbol => Integer}] the counters of the current request, created on first use
      def self.store = self.counters ||= {}
    end
    private_constant :RequestSequences

    config.chadcn = ActiveSupport::OrderedOptions.new
    config.chadcn.theme_dir = nil
    # Short `theme:list|use|import|check` aliases of the chadcn:theme:* tasks. Turn them off while the app defines its own
    # `theme:*` tasks (Rake would run both bodies). Read when the tasks load, so set it in config/application.rb.
    config.chadcn.theme_task_aliases = true
    # Hide the stubs tailwindcss-rails writes to app/assets/builds/tailwind/ from the served assets (TailwindStubFilter). Set it
    # to false to serve them yourself or to keep Propshaft untouched; the stubs then stay linked by `stylesheet_link_tag :app`.
    # Read by an engine initializer, so set it in config/application.rb (like theme_task_aliases).
    config.chadcn.hide_tailwind_stubs = true
    # Directory of ejected components, relative to the app root (nil: DEFAULT_OVERRIDE_DIR). Read by the loader initializer.
    config.chadcn.override_dir = nil

    # Sets up the loader of the gem's components. Not at require time (Bundler.require runs before the app is configured), but
    # before Rails sets its autoload paths, after config/application.rb and config/environments/*.rb. The override directory is
    # mounted on the app's main autoloader, so an ejected file is reloaded like any app code (dev/decisions/eject-override.md).
    # Precedence: config.chadcn.override_dir, then a value already set with Chadcn.configure, then the default.
    initializer "chadcn.loader", before: :set_autoload_paths do |app|
      configured = app.config.chadcn.override_dir
      override_dir = app.root.join(configured || Chadcn.config.override_dir || DEFAULT_OVERRIDE_DIR).to_s
      app.config.chadcn.resolved_override_dir = override_dir
      if Chadcn.setup?
        # A component was referenced before the app initialized (config/application.rb, an environment file): the loader is already up.
        next unless File.directory?(override_dir)

        raise Chadcn::Configuration::LateSettingError,
              "chadcn components were loaded before the application initialized, so #{override_dir} is ignored: " \
              "do not reference Chadcn components in config/application.rb or config/environments/*.rb"
      end
      Chadcn.configure { |config| config.override_dir = override_dir }
      Chadcn.setup(override_loader: ::Rails.autoloaders.main)
    end

    # config/initializers/*.rb load after the loader is set up: a late config.chadcn.override_dir would be ignored silently.
    initializer "chadcn.late_override_dir", after: :load_config_initializers do |app|
      configured = app.config.chadcn.override_dir
      next if configured.nil? || app.root.join(configured).to_s == app.config.chadcn.resolved_override_dir

      raise Chadcn::Configuration::LateSettingError,
            "config.chadcn.override_dir was changed after chadcn loaded its components, so it is ignored: " \
            "set it in config/application.rb or config/environments/*.rb"
    end

    # Generated ids (`dialog-1`, `dropdown-menu-2-trigger`) are numbered per request instead of per render: a page is several
    # renders (layout, view, Turbo frames), each with its own Phlex context. The store is reset by the executor around each request.
    initializer "chadcn.sequence_store" do
      Chadcn.configure { |config| config.sequence_store = RequestSequences.method(:store) }
    end

    initializer "chadcn.assets" do |app|
      if app.config.respond_to?(:assets)
        JAVASCRIPT_DIRECTORIES.map { |dir| root.join(dir).to_s }.each do |path|
          app.config.assets.paths << path unless app.config.assets.paths.map(&:to_s).include?(path)
        end
      end
    end

    # Sprockets apps only (Propshaft ignores the precompile list): the pinned files have to be declared precompiled.
    initializer "chadcn.sprockets" do |app|
      next unless defined?(::Sprockets::Railtie) && app.config.respond_to?(:assets)

      SprocketsAssets.install(app.config.assets, directories: JAVASCRIPT_DIRECTORIES.map { |dir| root.join(dir) })
    end

    initializer "chadcn.importmap", before: "importmap" do |app|
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << root.join("config/importmap.rb")
        app.config.importmap.cache_sweepers.concat(JAVASCRIPT_DIRECTORIES.map { |dir| root.join(dir) })
      end
    end

    # The engine's Tailwind entry (app/assets/tailwind/chadcn) is input of the Tailwind CLI, not a browser stylesheet, so
    # Propshaft must not serve it. tailwindcss-rails excludes the app's own app/assets/tailwind for the same reason. (Propshaft only
    # excludes load-path roots; the stub tailwindcss-rails writes to app/assets/builds/tailwind/ is hidden by TailwindStubFilter below.)
    initializer "chadcn.exclude_tailwind_inputs", before: "propshaft.append_assets_path" do |app|
      # Propshaft only: Sprockets has no excluded_paths (reading it on its options object answers nil).
      excluded = app.config.respond_to?(:assets) && app.config.assets.excluded_paths
      if excluded
        path = root.join("app/assets/tailwind")
        excluded << path unless excluded.map(&:to_s).include?(path.to_s)
      end
    end

    # Only where tailwindcss-rails writes stubs; a host without it (or without Propshaft) gets neither the hook nor a warning.
    initializer "chadcn.hide_tailwind_stubs" do |app|
      next unless defined?(::Tailwindcss) && defined?(::Propshaft::LoadPath) && app.config.respond_to?(:assets)

      TailwindStubFilter.install(
        ::Propshaft::LoadPath,
        stubs_dir: app.root.join(TAILWIND_STUBS_DIR),
        enabled: app.config.chadcn.hide_tailwind_stubs,
        logger: ::Rails.logger
      )
    end

    # Precedence: config.chadcn.theme_dir, then a value already set with Chadcn.configure, then the default.
    initializer "chadcn.theme" do |app|
      configured = app.config.chadcn.theme_dir
      next if configured.nil? && Chadcn.config.theme_dir

      # Pathname#join keeps an absolute value and roots a relative one at the app, whatever the working directory is.
      theme_dir = app.root.join(configured || DEFAULT_THEME_DIR).to_s
      Chadcn.configure { |config| config.theme_dir = theme_dir }
    end
  end
end

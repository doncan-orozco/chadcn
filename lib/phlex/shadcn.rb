# frozen_string_literal: true

require "monitor"
require "pathname"
require "phlex"
require "tailwind_merge"
require "zeitwerk"

# Phlex, the view library; this gem adds the shadcn/ui components under {Phlex::Shadcn}.
module Phlex
  # shadcn/ui components for Phlex.
  module Shadcn
    # Absolute path of the installed gem (where `lib`, `app` and `vendor` live); see {.root}.
    #
    # @return [Pathname]
    ROOT = Pathname.new(File.expand_path("../..", __dir__)).freeze

    # The gem's root directory (where `lib`, `app` and `vendor` live), e.g. for a Tailwind `@source` line.
    def self.root = ROOT

    # Zeitwerk loader of `lib/phlex/shadcn/**` (`Loader.eager_load` loads every component at once).
    #
    # @api private
    Loader = Zeitwerk::Loader.for_gem_extension(Phlex)
    # The engine (and the files under engine/ it requires itself) is required explicitly below, only inside an app, and is never
    # autoloaded or eager loaded.
    Loader.ignore(File.join(__dir__, "shadcn/engine.rb"), File.join(__dir__, "shadcn/engine"))
    # The loader is set up later (see .setup), once the override directory is known, so what the setup reads is required by hand and
    # kept away from the loader: the settings (the override directory is one of them) and overrides.rb, which is plain Ruby. Their
    # paths follow their constants, so a loader that did manage them would find the same names; they are ignored only because they
    # must exist before it is set up.
    Loader.ignore(File.join(__dir__, "shadcn/configuration.rb"), File.join(__dir__, "shadcn/overrides.rb"))
    require_relative "shadcn/configuration"
    require_relative "shadcn/overrides"
    @setup = false
    SETUP_LOCK = Monitor.new
    private_constant :SETUP_LOCK

    # @return [Phlex::Shadcn::Configuration] the gem's settings
    def self.config = (@config ||= Configuration.new)

    # Sets the gem's settings, once at boot: `Phlex::Shadcn.configure { |config| config.theme_dir = "/path/to/theme" }`.
    # @yieldparam config [Phlex::Shadcn::Configuration]
    def self.configure = yield(config)

    # Sets up the loader of the gem's components, ignoring the gem files the override directory shadows (they must be known before
    # the setup, or the gem wins silently; dev/decisions/eject-override.md), and mounts the override directory on the
    # {Phlex::Shadcn} namespace. Called once: at require time in a plain Phlex process, by the engine initializer in an app (before the
    # app's autoload paths, with the app's main autoloader as the override loader, so ejected files reload in development).
    #
    # @api private
    # @param override_loader [Zeitwerk::Loader, nil] the loader that owns the override directory; a loader of its own when nil
    # @return [void]
    def self.setup(override_loader: nil)
      SETUP_LOCK.synchronize do
        next if @setup

        dir = config.override_dir
        active = dir && File.directory?(dir)
        Loader.ignore(*Overrides.shadowed(dir)) if active
        Loader.setup
        @setup = true
        mount_overrides(dir, override_loader) if active
      end
    end

    # A loader that is given (the app's main autoloader) is set up by its owner, later; its own loader is set up here.
    def self.mount_overrides(dir, override_loader)
      own = override_loader.nil?
      override_loader ||= Zeitwerk::Loader.new.tap { |loader| loader.tag = "phlex-shadcn-overrides" }
      override_loader.push_dir(dir, namespace: self)
      return unless own

      override_loader.setup
      @override_loader = override_loader
    end
    private_class_method :mount_overrides

    # A component looked up before {.setup} ran (the framework is loaded but the app has not initialized yet): sets the loader up with
    # the settings known so far and retries. The engine initializer refuses to start when that would drop an override directory.
    #
    # @api private
    def self.const_missing(name)
      return super if @setup

      setup
      const_defined?(name, false) ? const_get(name, false) : super
    end

    # Loads every component, the ejected ones included.
    #
    # @api private
    # @return [void]
    def self.eager_load = [ Loader, @override_loader ].compact.each(&:eager_load)

    # @api private
    # @return [Boolean] whether {.setup} ran (the override directory can no longer change)
    def self.setup? = @setup
  end
end

if defined?(Rails::Engine)
  require "phlex/shadcn/engine"
else
  override_dir = ENV.fetch("PHLEX_SHADCN_OVERRIDE_DIR", "")
  Phlex::Shadcn.config.override_dir = File.expand_path(override_dir) unless override_dir.empty?
  Phlex::Shadcn.setup
end

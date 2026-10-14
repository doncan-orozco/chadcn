# frozen_string_literal: true

require "pathname"
require "phlex"
require "tailwind_merge"
require "zeitwerk"

module Phlex
  # shadcn/ui components for Phlex.
  module Shadcn
    ROOT = Pathname.new(File.expand_path("../..", __dir__)).freeze

    # The gem's root directory (where `lib`, `app` and `vendor` live), e.g. for a Tailwind `@source` line.
    def self.root = ROOT

    Loader = Zeitwerk::Loader.for_gem_extension(Phlex)
    # The engine is required explicitly below, only inside an app, and is never autoloaded or eager loaded.
    Loader.ignore(File.join(__dir__, "shadcn/engine.rb"))
    Loader.setup

    # @return [Phlex::Shadcn::Configuration] the gem's settings
    def self.config = (@config ||= Configuration.new)

    # Sets the gem's settings, once at boot: `Phlex::Shadcn.configure { |config| config.theme_dir = "/path/to/theme" }`.
    # @yieldparam config [Phlex::Shadcn::Configuration]
    def self.configure = yield(config)
  end
end

require "phlex/shadcn/engine" if defined?(Rails::Engine)

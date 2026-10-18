# frozen_string_literal: true

require_relative "boot"

# rails/engine has to be loaded before the gem (Bundler.require), see Phlex::Shadcn::Engine. Only the railties the harness needs:
# no Active Record, no database.
require "rails"
require "rails/engine"
require "action_controller/railtie"
require "action_view/railtie"
require "propshaft"

Bundler.require(*Rails.groups)

# The shared Phlex side of the parity harness (dev kit, not part of the gem).
require_relative "../../parity/lib/shadcn_parity"

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.1
    config.eager_load = false
    config.secret_key_base = "shadcn-parity-dummy-not-a-secret"
    config.hosts.clear
    config.api_only = false
    config.generators.system_tests = nil

    # One theme for both sides of the parity: the gem's shipped default theme (the React catalog reads the same directory).
    config.phlex_shadcn.theme_dir = Phlex::Shadcn.root.join("app/assets/tailwind/phlex-shadcn").to_s
  end
end

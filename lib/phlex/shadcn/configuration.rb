# frozen_string_literal: true

module Phlex
  module Shadcn
    # The settings of the gem, set once at boot with {Phlex::Shadcn.configure}. The engine forwards the host application's
    # `config.phlex_shadcn.*` values here.
    class Configuration
      # @return [String, nil] absolute directory that holds theme.css and presets/ (used by {Phlex::Shadcn::Theme})
      attr_accessor :theme_dir
    end
  end
end

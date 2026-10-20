# frozen_string_literal: true

module Phlex
  module Shadcn
    # The settings of the gem, set once at boot with {Phlex::Shadcn.configure}. The engine forwards the host application's
    # `config.phlex_shadcn.*` values here.
    class Configuration
      # Raised by a setting that the gem reads once, while it loads, when it is set after that moment.
      class LateSettingError < StandardError; end

      # @return [String, nil] absolute directory that holds theme.css and presets/ (used by {Phlex::Shadcn::Theme})
      attr_accessor :theme_dir

      # @return [String, nil] absolute directory of ejected components (`rails g phlex:shadcn:eject`): a file there with the path of a
      #   gem file (`button.rb`, `dialog/content.rb`) replaces it. An app on the gem's engine sets `config.phlex_shadcn.override_dir` (default
      #   `app/components/phlex_shadcn`, used when it exists); a plain Phlex app sets the environment variable
      #   `PHLEX_SHADCN_OVERRIDE_DIR` before it requires the gem. nil, or a missing directory, means nothing is ejected.
      attr_reader :override_dir

      # The directory is read once, while the gem's loader is set up, so it has to be set before that.
      #
      # @param value [String, nil] absolute directory
      # @raise [LateSettingError] when the gem's loader is already set up (with the engine: set it in config/application.rb or
      #   config/environments/*.rb; config/initializers/*.rb load too late)
      def override_dir=(value)
        if Phlex::Shadcn.setup? && value != @override_dir
          raise LateSettingError, "override_dir was set after phlex-shadcn loaded its components, so it would be ignored: " \
                                  "set config.phlex_shadcn.override_dir in config/application.rb or config/environments/*.rb"
        end

        @override_dir = value
      end
    end
  end
end

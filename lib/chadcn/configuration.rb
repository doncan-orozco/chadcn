# frozen_string_literal: true

module Chadcn
  # The settings of the gem, set once at boot with {Chadcn.configure}. The engine forwards the host application's
  # `config.chadcn.*` values here.
  class Configuration
    # Raised by a setting that the gem reads once, while it loads, when it is set after that moment.
    class LateSettingError < StandardError; end

    # @return [String, nil] absolute directory that holds theme.css and presets/ (used by {Chadcn::Theme})
    attr_accessor :theme_dir

    # @return [#call, nil] answers the Hash the counters behind the generated ids live in (`dialog-1`, `select-2-item-3`), called
    #   for every generated id; nil (the default) keeps them in the Phlex render context, so every top-level render numbers its
    #   roots from 1. A host that assembles a page from several renders sets a store that lives for the request: the engine
    #   installs one, reset by the Rails executor, so a layout and its view never repeat an id. Without Rails, a Rack host can set
    #   `-> { env[:chadcn_sequences] ||= {} }` from a middleware that holds the request's env.
    attr_accessor :sequence_store

    # @return [String, nil] absolute directory of ejected components (`rails g chadcn:eject`): a file there with the path of a
    #   gem file (`button.rb`, `dialog/content.rb`) replaces it. An app on the gem's engine sets `config.chadcn.override_dir` (default
    #   `app/components/chadcn`, used when it exists); a plain Phlex app sets the environment variable
    #   `CHADCN_OVERRIDE_DIR` before it requires the gem. nil, or a missing directory, means nothing is ejected.
    attr_reader :override_dir

    # The directory is read once, while the gem's loader is set up, so it has to be set before that.
    #
    # @param value [String, nil] absolute directory
    # @raise [LateSettingError] when the gem's loader is already set up (with the engine: set it in config/application.rb or
    #   config/environments/*.rb; config/initializers/*.rb load too late)
    def override_dir=(value)
      if Chadcn.setup? && value != @override_dir
        raise LateSettingError, "override_dir was set after chadcn loaded its components, so it would be ignored: " \
                                "set config.chadcn.override_dir in config/application.rb or config/environments/*.rb"
      end

      @override_dir = value
    end
  end
end

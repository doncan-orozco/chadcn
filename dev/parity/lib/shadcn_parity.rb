# frozen_string_literal: true

require "json"
require "pathname"
require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string/inflections"
require "zeitwerk"
require "chadcn"

# The Phlex side of the shadcn parity harness, shared by the dummy app (dev/dummy) and the host shims.
# It knows nothing about the host: scenarios are read from <dev>/port/scenarios (see ShadcnParity::Scenario::DIRECTORY).
module ShadcnParity
  unless const_defined?(:Loader, false)
    Loader = Zeitwerk::Loader.new
    Loader.tag = "shadcn_parity"
    Loader.push_dir(File.join(__dir__, "shadcn_parity"), namespace: self)
    Loader.setup
    private_constant :Loader
  end
end

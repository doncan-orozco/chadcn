# frozen_string_literal: true

require "phlex"
require "tailwind_merge"
require "zeitwerk"

module Phlex
  # shadcn/ui components for Phlex.
  module Shadcn
    Loader = Zeitwerk::Loader.for_gem_extension(Phlex)
    Loader.setup
  end
end

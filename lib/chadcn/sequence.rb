# frozen_string_literal: true

# The counters behind the ids a root generates when it is given no `id:` (`dialog-1`, `dropdown-menu-2-trigger`): one
# counter per root class, keyed by the root's `SEQUENCE_KEY`.
#
# By default a counter lives in the Phlex render context, so every top-level render numbers its roots from 1: deterministic,
# which the parity harness and the tests rely on, and unique within that render. A page a framework assembles from several
# renders (a layout, a view, Turbo frames) repeats the numbers, so a host moves the counters to a store that lives for the
# request: {Chadcn::Configuration#sequence_store} answers the Hash they live in (the engine installs one, reset by the Rails
# executor when the request completes). Radix numbers with React's `useId`, unique per tree; a caller that needs a known id passes
# `id:` to the root instead. A store that answers nil (no Hash for this request or thread) falls back to the render context.
#
# @api private
module Chadcn::Sequence
  # @param context [Hash] the Phlex render context of the root
  # @param key [Symbol] the counter (the root's `SEQUENCE_KEY`)
  # @return [Integer] the next number of that counter, in the configured store (or in the render context when the store is
  #   unset or answers nil)
  def self.next(context, key)
    counters = Chadcn.config.sequence_store&.call || context
    counters[key] = counters.fetch(key, 0) + 1
  end
end

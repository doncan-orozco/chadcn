# frozen_string_literal: true

# shadcn/ui Sonner (the Toaster wrapper of shadcn, over the sonner library). Spec: dev/port/specs/sonner.md.
# Behavior in controllers/chadcn/sonner_controller.js (`chadcn--sonner`) on the toast_stack primitive; styles in
# app/assets/tailwind/chadcn/sonner.css. No JavaScript library is involved.
#
# The family root. `Sonner.new(**options)` renders a {Toaster} with those options, so the block can use the generated helpers
# (`sonner.toast`) for toasts shown on load; the shadcn export itself is {Toaster} (also `Chadcn::Toaster`).
#
# Mount one Toaster in the layout. Toasts reach it three ways:
#
# * JavaScript: `window.Toaster.success("Saved", { description: "..." })`, the same call as sonner's `toast.success`.
# * Server: `Toaster.new(flash: flash)` renders the flash as toasts, and a Turbo Stream appends a {Toast} to the Toaster's id.
# * Any element: dispatch `chadcn--sonner:show` with `detail: { message:, type:, ... }`.
#
# @example Layout
#   render Chadcn::Toaster.new(flash: { notice: "Saved" }, close_button: true)
# @example Root with a toast shown on load (yielded-root helper form)
#   render Chadcn::Sonner.new(position: "top-center") do |sonner|
#     sonner.toast(type: :success, title: "Welcome back")
#   end
# @example Turbo Stream response
#   turbo_stream.append "toaster", Chadcn::Sonner::Toast.new(type: :success, title: "Saved")
#
# Generated helpers (each forwards `**attrs` and the block to the part): `toaster` and `toast`.
#
# @!method toaster(**attrs, &block)
#   Same as `render Sonner::Toaster.new(**attrs), &block`.
# @!method toast(**attrs, &block)
#   Same as `render Sonner::Toast.new(**attrs), &block`.
class Chadcn::Sonner < Chadcn::Base
  # Toast kinds, as sonner's `type`. `default` shows no icon.
  TYPES = %w[default success info warning error loading].freeze

  # @param options [Hash] the keywords of {Chadcn::Sonner::Toaster}
  def initialize(**options)
    @options = options
    super()
  end

  # @yieldparam sonner [Sonner] the root, exposing the generated part helpers
  # @return [void]
  def view_template
    render(Chadcn::Sonner::Toaster.new(**@options)) { yield self if block_given? }
  end
end

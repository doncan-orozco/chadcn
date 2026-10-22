# frozen_string_literal: true

# A toast the server asks the {Toaster} to show. Renders an inert `<template data-chadcn--sonner-toast>` that the Toaster's controller
# turns into a toast and removes: put it inside the Toaster (flash, `toasts:`, the block) or append it to the Toaster with a Turbo Stream.
#
# The title and description are plain text (never HTML). `action:` and `cancel:` are `{ label:, href:, event: }` hashes: `href` visits that
# http(s) URL, `event` is the `name` of the `chadcn--sonner:action` / `chadcn--sonner:cancel` event the Toaster dispatches.
#
# @example
#   render Chadcn::Sonner::Toast.new(type: :error, title: "Could not save", description: "Try again", action: { label: "Retry", event: "retry" })
class Chadcn::Sonner::Toast < Chadcn::Base
  # @param title [String, nil] the toast message; the block is the title when this is nil
  # @param description [String, nil] second line
  # @param type [String, Symbol, nil] one of {Chadcn::Sonner::TYPES}; nil shows a plain toast
  # @param id [String, nil] a stable id: showing the same id again updates the toast instead of adding one
  # @param duration [Integer, Symbol, nil] ms before it closes (default 4000); `:infinity` keeps it until dismissed
  # @param position [String, Symbol, nil] `top-left`, `top-center`, `top-right`, `bottom-left`, `bottom-center` or `bottom-right`
  # @param dismissible [Boolean, nil] false stops swipe and close button
  # @param close_button [Boolean, nil] overrides the Toaster's `close_button`
  # @param rich_colors [Boolean, nil] overrides the Toaster's `rich_colors`
  # @param invert [Boolean, nil] overrides the Toaster's `invert`
  # @param icon [Symbol, nil] `:none` shows no icon
  # @param action [Hash, nil] `{ label:, href:, event: }`
  # @param cancel [Hash, nil] `{ label:, href:, event: }`
  # @param toaster_id [String, nil] target a Toaster created with the same `toaster_id`
  # @param test_id [String, nil] `data-testid` of the toast
  # @param attrs [Hash] extra attributes for the template (`data:`)
  def initialize(title: nil, description: nil, type: nil, id: nil, duration: nil, position: nil, dismissible: nil, close_button: nil,
                 rich_colors: nil, invert: nil, icon: nil, action: nil, cancel: nil, toaster_id: nil, test_id: nil, **attrs)
    type = normalize_option(type)
    raise ArgumentError, "unknown toast type #{type.inspect} (#{Chadcn::Sonner::TYPES.join(', ')})" if type && !Chadcn::Sonner::TYPES.include?(type)

    @title = title
    @description = description
    @options = {
      type:, id:, duration: infinite?(duration) ? "Infinity" : duration, position: normalize_option(position),
      dismissible:, close_button:, rich_colors:, invert:, icon: normalize_option(icon), toaster_id:, test_id:,
      action_label: action&.dig(:label), action_href: action&.dig(:href), action_event: action&.dig(:event),
      cancel_label: cancel&.dig(:label), cancel_href: cancel&.dig(:href), cancel_event: cancel&.dig(:event)
    }
    @attrs = attrs
    super()
  end

  # @return [void]
  def view_template(&block)
    data = @options.compact.transform_values { |value| [ true, false ].include?(value) ? value.to_s : value }
    template(**merge_attrs({ data: { chadcn__sonner_toast: "", **data } }, @attrs)) do
      div(data: { title: "" }) { @title ? plain(@title.to_s) : (yield if block) }
      div(data: { description: "" }) { plain(@description.to_s) } if @description
    end
  end

  private

  def infinite?(duration) = duration.to_s.casecmp?("infinity")
end

# frozen_string_literal: true

# Two Turbo-Drive pages for the real-visit browser test. Not a parity scenario: no React twin, no entry in dev/port/scenarios.
class TurboRoundTripsController < ApplicationController
  def show
    return head :not_found unless TurboRoundTrip::Page::PAGES.include?(params[:page])

    render TurboRoundTrip::Page.new(page: params[:page]), layout: false
  end
end

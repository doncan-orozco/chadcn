# frozen_string_literal: true

# One Turbo-Drive page per chart family for the chadcn--chart browser test (test/javascript/chart.test.mjs). Not a parity scenario: the
# parity scenarios of the chart (dev/port/scenarios/chart.json) cover hover and keyboard against recharts; this page covers what the
# runner cannot express (events, touch, Turbo cache restore).
class ChartDemosController < ApplicationController
  def show
    return head :not_found unless ChartDemo::Page::FAMILIES.include?(params[:family])

    render ChartDemo::Page.new(family: params[:family]), layout: false
  end
end

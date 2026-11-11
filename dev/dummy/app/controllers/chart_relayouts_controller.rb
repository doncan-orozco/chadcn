# frozen_string_literal: true

# A host of the chart re-layout for the browser tests (test/javascript/chart_remeasure.test.mjs): the chart of a parity scenario with
# `relayout_url:` pointing at this action, laid out with the container keywords `Chadcn::Chart::Container.relayout_options` reads from
# the request, which is what an application's action does (dev/port/specs/chart.md, "Behavior", "Resize and re-measure"). Without
# `chart[...]` parameters it is the parity page of the scenario plus the re-layout values.
class ChartRelayoutsController < ApplicationController
  SCENARIOS = %w[legend__bottom resize__pie-320].freeze

  def show
    return head :not_found unless SCENARIOS.include?(params[:scenario])

    tree = ShadcnParity::Scenario.find("chart", params[:scenario]).fetch("tree")
    props = tree.fetch("props")
    options = Chadcn::Chart::Container.relayout_options(params, id: props.fetch("id"))
    tree = tree.merge("props" => props.merge("relayoutUrl" => request.path, **container_props(options)))
    html = view_context.render(ShadcnParity::TreeRenderer.new(tree: tree, component: "chart"))
    render ShadcnParity::Page.new(html: html), layout: false
  end

  private

  # The scenario's tree names the container keywords in React's camelCase.
  def container_props(options) = options.to_h { |keyword, value| [ keyword.to_s.camelize(:lower), value ] }
end

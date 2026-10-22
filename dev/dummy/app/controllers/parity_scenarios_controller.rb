# frozen_string_literal: true

# Phlex side of the shadcn port parity harness. React twin: dev/react-shadcn-catalog/src/parity/Harness.tsx.
# Contract: .ai/skills/shadcn-port/references/parity-gates.md.
class ParityScenariosController < ApplicationController
  def show
    scenario = ShadcnParity::Scenario.find(params[:component], params[:scenario])
    tree = ShadcnParity::TreeRenderer.new(tree: scenario.fetch("tree"), component: params[:component], dx: params[:dx])
    # The React harness stubs Math.random = 0.5, so the oracle menu skeleton width is floor(0.5 * 40) + 50 = 70.
    html = Chadcn::Sidebar::MenuSkeleton.with_pinned_width(70) { view_context.render(tree) }
    render ShadcnParity::Page.new(html: html), layout: false
  rescue ShadcnParity::Scenario::NotFound => e
    render_error(e, :not_found)
  rescue StandardError => e
    Rails.logger.error("[parity] #{e.class}: #{e.message}\n#{e.backtrace.first(8).join("\n")}")
    render_error(e, :internal_server_error)
  end

  private

  def render_error(error, status)
    render ShadcnParity::Page.new(error: "#{error.class}: #{error.message}"), layout: false, status: status
  end
end

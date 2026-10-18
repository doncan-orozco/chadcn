# frozen_string_literal: true

# URL paths are the contract of the parity runner (.claude/scripts/shadcn/parity_run.mjs) and of the React twin.
Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  get "design-system/parity/:component/:scenario", to: "parity_scenarios#show", as: :parity_scenario
  resource :theme_panel, only: :show, path: "design-system/theme-panel"
end

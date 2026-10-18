# frozen_string_literal: true

# Live theme preview (preset select, radius slider, light/dark, contrast badges, "Copy CSS").
class ThemePanelsController < ApplicationController
  def show
    render ShadcnParity::Page.new(html: view_context.render(ShadcnParity::ThemePanel.new)), layout: false
  end
end

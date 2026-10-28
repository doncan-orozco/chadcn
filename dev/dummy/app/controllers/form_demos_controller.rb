# frozen_string_literal: true

# Two Turbo-Drive pages for the Form live-validity browser test (test/javascript/form.test.mjs). Not a parity scenario: no React twin.
class FormDemosController < ApplicationController
  def show
    return head :not_found unless FormDemo::Page::PAGES.include?(params[:page])

    render FormDemo::Page.new(page: params[:page]), layout: false
  end
end

# frozen_string_literal: true

# The gem's demo: every ported component, generated from dev/port/scenarios.
class CatalogController < ApplicationController
  def index
    render Catalog::Index.new(entries: Catalog::Entries.all)
  end
end

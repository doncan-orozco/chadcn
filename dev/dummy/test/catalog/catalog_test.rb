# frozen_string_literal: true

require "test_helper"
require Rails.root.join("../catalog/generator").to_s

class CatalogTest < ActionDispatch::IntegrationTest
  # Components the generator leaves out on purpose (every light scenario uses harness-only nodes) have no entry to find.
  SKIPPED = begin
    generator = Chadcn::CatalogData.new(Rails.root.join("../..").to_s)
    generator.build
    generator.skipped.map { |item| item[:component] }
  end.freeze
  SCENARIO_FILES = Dir[ShadcnParity::Scenario::DIRECTORY.join("*.json").to_s].map { |f| File.basename(f, ".json") }
    .select { |name| Catalog::Entries.ported?(name) && !SKIPPED.include?(name) }.freeze

  test "scenario files of ported components are found" do
    assert_operator SCENARIO_FILES.size, :>, 10
  end

  %w[/ /catalog].each do |path|
    test "GET #{path} renders an entry for each scenario-backed component" do
      get path

      assert_response :success
      SCENARIO_FILES.each do |component|
        assert_select "section#catalog-#{component}", 1, "no catalog entry for dev/port/scenarios/#{component}.json"
      end
      assert_select "[data-parity-error]", false
    end
  end

  test "the page links the theme panel and no preview failed" do
    get "/"

    assert_select "a[href='/design-system/theme-panel']"
    assert_select "p.text-destructive", false
  end

  test "parity and theme panel routes keep working" do
    get "/design-system/theme-panel"
    assert_response :success

    get "/design-system/parity/button/defaults"
    assert_response :success
  end

  test "a scenario file without an entry is reported" do
    entries = Catalog::Entries.all.map(&:component)
    missing = SCENARIO_FILES - entries

    assert_empty missing, "scenario files without a catalog entry (no light scenario?): #{missing.join(', ')}"
  end

  test "the catalog uses no host-only constants" do
    sources = Dir[Rails.root.join("app/components/catalog/*.rb").to_s] + [ Rails.root.join("app/controllers/catalog_controller.rb").to_s ]
    sources.each do |file|
      refute_match(/Views::Base|Components::Parity|Components::Shared/, File.read(file), file)
    end
  end
end

# frozen_string_literal: true

# One entry per ported component, from the packaged Chadcn::Catalog (generated from `dev/port/scenarios`, `rake catalog:generate`), so the
# demo can never drift from the ported components: a new component appears automatically. This only adds the page anchor.
module Catalog
  module Entries
    Entry = Struct.new(:component, :title, :scenario_id, :scenario_count, :tree, keyword_init: true) do
      def anchor = "catalog-#{component}"
    end

    module_function

    def all
      Chadcn::Catalog.entries.map { |entry| Entry.new(**entry.to_h) }
    end

    # Scenario files that start with "_" are primitives/harness fixtures, not components; a component is a gem file
    # (Chadcn::Overrides.component?, the same test the catalog generator applies).
    def ported?(component)
      !component.start_with?("_") && Chadcn::Overrides.component?(component)
    end
  end
end

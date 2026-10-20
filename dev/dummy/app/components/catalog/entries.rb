# frozen_string_literal: true

# One entry per `dev/port/scenarios/<component>.json` whose Phlex::Shadcn class exists, previewing its first plain (light)
# default scenario, so the demo can never drift from the ported components: a new component appears automatically.
# Harness-only nodes of a scenario (`data-testid` outside/next/neutral probes) are pruned.
module Catalog
  module Entries
    Entry = Struct.new(:component, :title, :scenario_id, :scenario_count, :tree, keyword_init: true) do
      def anchor = "catalog-#{component}"
    end

    PROBES = %w[outside next neutral].freeze

    module_function

    def all(directory: ShadcnParity::Scenario::DIRECTORY)
      Dir[directory.join("*.json").to_s].filter_map do |file|
        component = File.basename(file, ".json")
        next unless ported?(component)

        build(component, JSON.parse(File.read(file)).fetch("scenarios", []))
      end.sort_by(&:component)
    end

    # Scenario files that start with "_" are primitives/harness fixtures, not components.
    def ported?(component)
      !component.start_with?("_") && Phlex::Shadcn.const_defined?(component.tr("-", "_").camelize, false)
    end

    def build(component, scenarios)
      preview = scenarios.find { |s| s["id"].start_with?("default") && !s["dark"] } || scenarios.find { |s| !s["dark"] }
      return unless preview

      Entry.new(component: component, title: component.tr("-", " ").capitalize, scenario_id: preview["id"],
                scenario_count: scenarios.size, tree: prune(preview.fetch("tree")))
    end

    def prune(node)
      return node unless node.is_a?(Hash)

      children = Array(node["children"]).reject { |child| child.is_a?(Hash) && PROBES.include?(child.dig("props", "data-testid")) }
      node.merge("children" => children.map { |child| prune(child) })
    end
  end
end

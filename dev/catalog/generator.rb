# frozen_string_literal: true

require "json"

module Chadcn
  # Builds lib/chadcn/catalog/entries.json (what Chadcn::Catalog reads) from the parity scenarios in dev/port/scenarios: per ported
  # component its first plain (light) default scenario, with the harness-only probe nodes (`data-testid` outside/next/neutral)
  # pruned. `rake catalog:check` fails when the committed file differs. The output is deterministic (sorted, no timestamps).
  class CatalogData
    OUTPUT = "lib/chadcn/catalog/entries.json"
    SCENARIOS = "dev/port/scenarios"
    PROBES = %w[outside next neutral].freeze

    # @param root [String] the repository root (the one holding lib/ and dev/)
    def initialize(root)
      @root = root
    end

    # @return [String] the generated file content
    def build
      "#{JSON.generate({ "entries" => entries })}\n"
    end

    def write = File.write(File.join(@root, OUTPUT), build)

    def drifted? = !File.exist?(path) || File.read(path, encoding: "UTF-8") != build

    private

    def path = File.join(@root, OUTPUT)

    def entries
      Dir[File.join(@root, SCENARIOS, "*.json")].filter_map do |file|
        component = File.basename(file, ".json")
        next if component.start_with?("_") || !Chadcn.const_defined?(constant(component), false)

        entry(component, JSON.parse(File.read(file, encoding: "UTF-8")).fetch("scenarios", []))
      end.sort_by { |entry| entry["component"] }
    end

    def constant(component) = component.split(/[-_]/).map { |word| word.sub(/\A./, &:upcase) }.join

    def entry(component, scenarios)
      preview = scenarios.find { |s| s["id"].start_with?("default") && !s["dark"] } || scenarios.find { |s| !s["dark"] }
      return unless preview

      { "component" => component, "scenario_id" => preview["id"], "scenario_count" => scenarios.size, "tree" => prune(preview.fetch("tree")) }
    end

    def prune(node)
      return node unless node.is_a?(Hash)

      children = Array(node["children"]).reject { |child| child.is_a?(Hash) && PROBES.include?(child.dig("props", "data-testid")) }
      node.merge("children" => children.map { |child| prune(child) })
    end
  end
end

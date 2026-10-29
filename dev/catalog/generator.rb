# frozen_string_literal: true

require "json"

module Chadcn
  # Builds lib/chadcn/catalog/entries.json (what Chadcn::Catalog reads) from the parity scenarios in dev/port/scenarios: per ported
  # component its first plain (light) default scenario, with the harness-only probe nodes (`data-testid` outside/next/neutral)
  # pruned. A scenario whose tree holds a harness-scope node (`_Name`, capitalized: a parity-harness fixture the real renderer cannot
  # resolve; the recharts parts `_BarChart`, `_Bar`... are not, the renderer maps them) cannot be the preview: the component is then left out (no other scenario is substituted) and listed in #skipped. `rake catalog:check` fails when the committed file differs. The output is deterministic (sorted, no timestamps).
  class CatalogData
    OUTPUT = "lib/chadcn/catalog/entries.json"
    SCENARIOS = "dev/port/scenarios"
    PROBES = %w[outside next neutral].freeze
    # `_Each` is the renderer's own iteration marker (Chadcn::Catalog::TreeRenderer), so it is not harness-only.
    HARNESS_NODE = /\A_(?!Each\z)[A-Z]/
    # The `_Name` nodes the renderer resolves itself (Chadcn::Catalog::ChartScope), so they can be part of a preview.
    RENDERABLE_NODES = Chadcn::Catalog::ChartScope::RECHARTS_PARTS.map { |name| "_#{name}" }.freeze

    # @return [Array<Hash>] the components left out of the last #build, each `{ component:, reason: }`
    attr_reader :skipped

    # @param root [String] the repository root (the one holding lib/ and dev/)
    def initialize(root)
      @root = root
      @skipped = []
    end

    # @return [String] the generated file content
    def build
      @skipped = []
      "#{JSON.generate({ "entries" => entries })}\n"
    end

    # Writes {OUTPUT} under the root.
    def write = File.write(File.join(@root, OUTPUT), build)

    # @return [Boolean] whether the committed file differs from what {#build} produces
    def drifted? = !File.exist?(path) || File.read(path, encoding: "UTF-8") != build

    private

    def path = File.join(@root, OUTPUT)

    def entries
      Dir[File.join(@root, SCENARIOS, "*.json")].filter_map do |file|
        component = File.basename(file, ".json")
        next if component.start_with?("_") || !ported?(component)

        entry(component, JSON.parse(File.read(file, encoding: "UTF-8")).fetch("scenarios", []))
      end.sort_by { |entry| entry["component"] }
    end

    # A component is ported when the gem ships its file (Chadcn::Overrides.component?, the definition the eject generator uses); a
    # directory alone (the private math of an unfinished component) autovivifies the namespace without making it renderable.
    def ported?(component) = Chadcn::Overrides.component?(component)

    def constant(component) = component.split(/[-_]/).map { |word| word.sub(/\A./, &:upcase) }.join

    def entry(component, scenarios)
      light = scenarios.reject { |scenario| scenario["dark"] }
      preview = light.find { |scenario| scenario["id"].start_with?("default") } || light.first
      return skip(component, "no light scenario") unless preview

      tree = prune(preview.fetch("tree"))
      return skip(component, "preview scenario uses harness-only nodes") if harness_node?(tree)

      { "component" => component, "scenario_id" => preview["id"], "scenario_count" => scenarios.size, "tree" => tree }
    end

    def skip(component, reason)
      @skipped << { component:, reason: }
      nil
    end

    def harness_node?(node)
      case node
      when Hash then harness_name?(node["c"].to_s) || node.each_value.any? { |value| harness_node?(value) }
      when Array then node.any? { |item| harness_node?(item) }
      else false
      end
    end

    def harness_name?(name) = name.match?(HARNESS_NODE) && !RENDERABLE_NODES.include?(name)

    def prune(node)
      return node unless node.is_a?(Hash)

      children = Array(node["children"]).reject { |child| child.is_a?(Hash) && PROBES.include?(child.dig("props", "data-testid")) }
      node.merge("children" => children.map { |child| prune(child) })
    end
  end
end

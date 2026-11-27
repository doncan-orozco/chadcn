# frozen_string_literal: true

require "json"

module Chadcn
  # Builds lib/chadcn/catalog/entries.json (what Chadcn::Catalog reads) from the parity scenarios in dev/port/scenarios: per ported
  # component its first plain (light) default scenario, with the harness-only probe nodes (`data-testid` outside/next/neutral)
  # pruned. A scenario whose tree holds a harness-scope node (`_Name`, capitalized: a parity-harness fixture the real renderer
  # cannot resolve; the recharts parts `_BarChart`, `_Bar`... are not, the renderer maps them) cannot be the preview: the component
  # is then left out (no other scenario is substituted) and listed in #skipped. `rake catalog:check` fails when the committed file
  # differs. The output is deterministic (sorted, no timestamps).
  class CatalogData
    OUTPUT = "lib/chadcn/catalog/entries.json"
    SCENARIOS = "dev/port/scenarios"
    PROBES = %w[outside next neutral].freeze
    # `_Each` is the renderer's own iteration marker (Chadcn::Catalog::TreeRenderer), so it is not harness-only.
    # Accessible names the catalog adds to demo controls that the parity scenarios leave bare (the scenarios mirror the React oracle,
    # which has no label either). Applied by node name; a name the scenario already sets (`aria-label`, `aria-labelledby`) wins.
    LABELS = {
      "Checkbox" => "Accept terms and conditions", "Switch" => "Airplane mode", "Input" => "Email", "Textarea" => "Message",
      "InputGroupInput" => "Search", "ComboboxInput" => "Framework", "CommandInput" => "Search commands",
      "InputOTP" => "One-time password", "ToggleGroup" => "Text formatting", "ResizableHandle" => "Resize panels", "RadioGroup" => "Layout density", "MessageScrollerButton" => "Scroll to latest message",
      "NativeSelect" => "Status"
    }.freeze
    # Bare `_button` demo actions (the oracle scenarios render a plain <button>) become a styled Chadcn::Button, by their text.
    BUTTONS = { "Create Project" => {}, "Import Project" => { "variant" => "outline" }, "Action" => { "variant" => "outline", "size" => "sm" } }.freeze
    # Extra classes the catalog gives a demo part so it meets contrast (the component's own classes stay the verbatim shadcn ones):
    # muted-foreground on muted is under 4.5:1 once the page paints over it, so the avatar initials use the foreground token.
    CLASS_NAMES = { "AvatarFallback" => "text-foreground" }.freeze
    # Components whose demo needs another prop to be nameable: a one-value Slider thumb takes no label (Radix 1:1), a two-value one does.
    PROPS = { "Slider" => { "defaultValue" => [ 25, 75 ] }, "ComboboxInput" => { "triggerLabel" => "Show options" } }.freeze
    # `_BarChart`, `_PieChart`...: the svg (`role="application"`) is named "Bar chart", "Pie chart"...
    CHART_NODE = /\A_(?<kind>[A-Z][a-z]+(?:Radial)?[A-Za-z]*?)Chart\z/
    HARNESS_NODE = /\A_(?!Each\z)[A-Z]/

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
      when Array then node.any? { |child| harness_node?(child) }
      else false
      end
    end

    def harness_name?(name) = name.match?(HARNESS_NODE) && !Chadcn::Catalog::ChartScope.resolvable_node?(name)

    def prune(node)
      return node unless node.is_a?(Hash)

      children = Array(node["children"]).reject { |child| child.is_a?(Hash) && PROBES.include?(child.dig("props", "data-testid")) }
      pruned = node.merge("children" => children.map { |child| prune(child) })
      return button(pruned) if pruned["c"] == "_button" && BUTTONS.key?(Array(pruned["children"]).first)

      props = styled(node, labelled(node))
      props.equal?(node["props"]) ? pruned : pruned.merge("props" => props)
    end

    def button(node) = node.merge("c" => "Button", "props" => (node["props"] || {}).merge(BUTTONS.fetch(node["children"].first)))

    def styled(node, props)
      klass = CLASS_NAMES[node["c"].to_s]
      klass ? (props || {}).merge("className" => [ props&.dig("className"), klass ].compact.join(" ")) : props
    end

    def labelled(node)
      name = node["c"].to_s
      props = node["props"]
      return props unless LABELS.key?(name) || PROPS.key?(name) || name.match?(CHART_NODE)
      return props if props&.key?("aria-label") || props&.key?("aria-labelledby")

      extra = PROPS.fetch(name, {}).reject { |key, _| props&.key?(key) }
      label = LABELS[name] || (name.match(CHART_NODE) && "#{name.match(CHART_NODE)[:kind].gsub(/(?<=.)(?=[A-Z])/, ' ')} chart")
      (props || {}).merge(extra).merge(label ? { "aria-label" => label } : {})
    end
  end
end

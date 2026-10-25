# frozen_string_literal: true

require "json"

module Chadcn
  # A ready-made catalog of the ported components: one {Entry} per component, each carrying a representative example as a
  # JSON tree that {Catalog::TreeRenderer} renders with the real components. A host builds its own component gallery
  # page from it, and the examples cannot drift from the components because they are generated from the same scenarios the
  # 1:1 parity gates check (`bundle exec rake catalog:generate`).
  #
  # ```ruby
  # Chadcn::Catalog.entries.each do |entry|
  #   h2 { entry.title }
  #   render Chadcn::Catalog::TreeRenderer.new(tree: entry.tree, component: entry.component)
  # end
  # ```
  #
  # See docs/catalog.md for the tree format.
  module Catalog
    # One component of the catalog.
    #
    # @!attribute [r] component
    #   @return [String] the shadcn name of the component, e.g. `"button-group"` (the `Chadcn::ButtonGroup` root)
    # @!attribute [r] title
    #   @return [String] a display title, e.g. `"Button group"`
    # @!attribute [r] scenario_id
    #   @return [String] the id of the parity scenario the example comes from, e.g. `"default"`
    # @!attribute [r] scenario_count
    #   @return [Integer] how many scenarios the component has in the parity gates (variants, sizes, states, interactions)
    # @!attribute [r] tree
    #   @return [Hash] the example, a JSON tree for {TreeRenderer}; light theme, without the harness-only probe nodes
    Entry = Struct.new(:component, :title, :scenario_id, :scenario_count, :tree, keyword_init: true)

    # Where the generated entries live (written by `rake catalog:generate`, packaged with the gem).
    #
    # @api private
    DATA = File.expand_path("catalog/entries.json", __dir__)

    class << self
      # Every ported component with an example, sorted by component name. The entries are built once and frozen; the result
      # is a new Array per call, so a host may sort or filter it.
      #
      # @return [Array<Entry>]
      def entries = all.dup

      # The entry of one component.
      #
      # @param component [String, Symbol] the shadcn name, e.g. `"dialog"` or `:button_group`
      # @return [Entry, nil] nil when the component has no example
      def find(component)
        name = component.to_s.tr("_", "-")
        all.find { |entry| entry.component == name }
      end

      private

      def all
        @all ||= JSON.parse(File.read(DATA, encoding: "UTF-8")).fetch("entries").map do |data|
          component = data.fetch("component")
          Entry.new(component:, title: component.tr("-", " ").capitalize, scenario_id: data.fetch("scenario_id"),
                    scenario_count: data.fetch("scenario_count"), tree: deep_freeze(data.fetch("tree"))).freeze
        end.freeze
      end

      def deep_freeze(value)
        case value
        when Hash then value.each_value { |v| deep_freeze(v) }
        when Array then value.each { |v| deep_freeze(v) }
        end
        value.freeze
      end
    end
  end
end

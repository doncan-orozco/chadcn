# frozen_string_literal: true

require "test_helper"

class CatalogTest < Minitest::Test
  def render_tree(tree, **) = Chadcn::Catalog::TreeRenderer.new(tree:, **).call

  def test_entries_are_sorted_ported_components_with_a_light_example
    entries = Chadcn::Catalog.entries

    assert_operator entries.size, :>, 50
    assert_equal entries.map(&:component).sort, entries.map(&:component)
    entries.each do |entry|
      assert Chadcn.const_defined?(entry.component.split("-").map(&:capitalize).join, false), "#{entry.component} has no Chadcn class"
      assert_operator entry.scenario_count, :>=, 1
      refute_predicate entry.scenario_id, :empty?
    end
  end

  def test_entry_fields
    entry = Chadcn::Catalog.find(:button_group)

    assert_equal "button-group", entry.component
    assert_equal "Button group", entry.title
    assert_equal "ButtonGroup", entry.tree.fetch("c")
  end

  def test_find_returns_nil_for_an_unknown_component
    assert_nil Chadcn::Catalog.find("nope")
  end

  def test_entries_returns_a_new_array_of_frozen_entries
    entries = Chadcn::Catalog.entries
    entries.clear

    refute_empty Chadcn::Catalog.entries
    assert_predicate Chadcn::Catalog.find("button"), :frozen?
    assert_predicate Chadcn::Catalog.find("button").tree, :frozen?
  end

  def test_no_entry_keeps_a_harness_probe_node
    Chadcn::Catalog.entries.each { |entry| refute_match(/"data-testid":"(outside|next|neutral)"|"c":"_Probe/, JSON.generate(entry.tree), entry.component) }
  end

  def test_every_entry_renders_with_the_real_components
    Chadcn::Catalog.entries.each do |entry|
      html = render_tree(entry.tree, component: entry.component)

      refute_predicate html, :empty?, entry.component
    end
  end

  def test_a_component_renders_the_same_as_the_hand_written_call
    tree = { "c" => "Button", "props" => { "variant" => "outline" }, "children" => [ "Save" ] }

    assert_equal Chadcn::Button.new(variant: "outline").call { "Save" }, render_tree(tree, component: "button")
  end

  def test_raw_elements_icons_and_class_name_mapping
    html = render_tree({ "c" => "_div", "props" => { "className" => "p-1", "data-x" => "1", "tabIndex" => 0 }, "children" => [ "<icon:check> ok" ] })

    assert_includes html, 'class="p-1"'
    assert_includes html, 'data-x="1"'
    assert_includes html, 'tabindex="0"'
    assert_includes html, "<svg"
    assert_includes html, " ok"
  end

  def test_a_nested_part_resolves_against_its_root
    tree = { "c" => "Card", "children" => [ { "c" => "CardHeader", "children" => [ { "c" => "CardTitle", "children" => [ "T" ] } ] } ] }
    html = render_tree(tree, component: "card")

    assert_includes html, 'data-slot="card-header"'
    assert_includes html, 'data-slot="card-title"'
  end

  def test_unknown_components_and_malformed_nodes_raise
    assert_raises(Chadcn::Catalog::TreeRenderer::Error) { render_tree({ "c" => "Nope" }) }
    assert_raises(Chadcn::Catalog::TreeRenderer::Error) { render_tree({ "c" => "_Probe" }) }
    assert_raises(Chadcn::Catalog::TreeRenderer::Error) { render_tree({ "c" => "Button", "children" => [ 1 ] }) }
  end

  def test_date_and_locale_markers_are_converted_at_any_depth
    renderer = Chadcn::Catalog::TreeRenderer.new(tree: {})
    value = { "a" => "$date:2026-03-15", "b" => [ "$locale:es", { "x" => "$date:2026-03-15", "y" => "$date:2026-1-5" } ] }

    assert_equal({ "a" => "2026-03-15", "b" => [ "es", { "x" => "2026-03-15", "y" => "$date:2026-1-5" } ] }, renderer.send(:plain_values, value))
  end
end

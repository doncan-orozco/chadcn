# frozen_string_literal: true

require "test_helper"
require "open3"
require "rbconfig"

class SmokeTest < Minitest::Test
  def test_has_a_version
    assert_match(/\A\d+\.\d+\.\d+/, Chadcn::VERSION)
  end

  def test_loads_without_rails
    assert_nil defined?(Rails), "the gem core must load without Rails"
  end

  # A clean process is the only real proof: the test process itself may have loaded anything. It eager-loads the gem, renders a
  # simple part, a compound with generated helpers and a part that serializes JSON options, then checks that no ActiveSupport
  # file was loaded and no core class was extended.
  CLEAN_PROCESS_SCRIPT = <<~RUBY
    require "chadcn"
    Chadcn::Loader.eager_load

    page = Class.new(Phlex::HTML) do
      def view_template
        render(Chadcn::Button.new(variant: "outline")) { plain "Go" }
        render(Chadcn::Card.new) { |card| card.header { card.title { plain "T" } } }
        render(Chadcn::Popover.new) do
          render(Chadcn::Popover::Trigger.new) { plain "open" }
          render(Chadcn::Popover::Content.new) { plain "body" }
        end
      end
    end

    html = page.new.call
    loaded = $LOADED_FEATURES.grep(/active_support/)
    abort("ActiveSupport was loaded: \#{loaded.first(3).inspect}") unless loaded.empty?
    abort("Rails was touched: \#{defined?(Rails).inspect}") if defined?(Rails)
    abort("the Rails engine was loaded in a plain Phlex process") if defined?(Chadcn::Engine)
    abort("a core class was extended") if "".respond_to?(:blank?) || {}.respond_to?(:deep_merge) || [].respond_to?(:compact_blank)
    helpers = %i[blank_value? filled? unless_blank reject_blank merge_deep snake_case unqualified]
    leaked = [ Object, String, Hash, Array, Enumerable ].flat_map { |mod| helpers.select { |name| mod.method_defined?(name) }.map { |name| "\#{mod}#\#{name}" } }
    abort("a Values helper leaked out of its refinement: \#{leaked.inspect}") unless leaked.empty?
    print html
  RUBY

  def test_loads_and_renders_in_a_clean_process_without_activesupport
    library = File.expand_path("../lib", __dir__)
    output, status = Open3.capture2e(RbConfig.ruby, "-I", library, "-e", CLEAN_PROCESS_SCRIPT)

    assert_predicate status, :success?, output
    assert_includes output, 'data-slot="button"'
    assert_includes output, 'data-slot="card-title"'
    assert_includes output, 'data-slot="popover-trigger"'
  end

  def test_eager_loads_every_file
    Chadcn::Loader.eager_load

    assert_kind_of Module, Chadcn
  end
end

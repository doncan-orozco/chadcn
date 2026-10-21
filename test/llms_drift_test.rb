# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "../dev/llms/signature"

# llms.txt, llms-full.txt and skills/phlex-shadcn/SKILL.md are generated (`bundle exec rake llms:generate`) from the YARD docs and the
# Stimulus controllers. This test is the same check as `rake llms:check`, inside `rake test`, and proves the check notices a changed component.
class LlmsDriftTest < Minitest::Test
  GEM_DIR = File.expand_path("..", __dir__)
  CLI = File.join(GEM_DIR, "dev/llms/cli.rb")

  def test_committed_llms_files_match_the_generated_ones
    out, status = run_cli("check", GEM_DIR)

    assert_predicate status, :success?, out
  end

  def test_llms_full_lists_every_component_the_registry_knows
    require "yard"
    YARD::Registry.clear
    YARD.parse(Dir[File.join(GEM_DIR, "lib/**/*.rb")].reject { |path| path.end_with?("icons/catalog.rb") })
    components = YARD::Registry.all(:class).select { |c| c.namespace.path == "Phlex::Shadcn" && c.superclass&.path == "Phlex::Shadcn::Base" }
    components = components.reject { |c| c.tag(:api)&.text == "private" || c.visibility != :public || c.name == :Icon }
    full = File.read(File.join(GEM_DIR, "llms-full.txt"))

    assert_equal 54, components.size
    components.each do |component|
      assert_includes full, "## #{component.name}\n", "#{component.name} is missing from llms-full.txt"
      assert_includes full, "Phlex::Shadcn::#{component.name}.new(", "#{component.name} has no constructor line"
    end
  end

  # Every keyword-default literal the gem may write, as the source of a method: YARD slices it from the text and keeps a different
  # trailing delimiter per Ruby, so the renderer must give one exact string wherever this runs.
  SIGNATURE_SOURCE = <<~RUBY
    class Sample
      def call(neg_int: -4, neg_float: -1.5, array: [ 1, :two ], hash: { a: 1, "b" => 2 }, regexp: /ab+c/i, string: "s", symbol: :sym,
               words: %w[a b], call: Foo.bar(1), last: -4)
      end
    end
  RUBY
  SIGNATURE_EXPECTED = '(neg_int: -4, neg_float: -1.5, array: [ 1, :two ], hash: { a: 1, "b" => 2 }, regexp: /ab+c/i, string: "s", ' \
                       "symbol: :sym, words: %w[a b], call: Foo.bar(1), last: -4)"

  def test_signature_renders_every_default_literal_identically_on_every_ruby
    require "yard"
    YARD::Registry.clear
    begin
      YARD.parse_string(SIGNATURE_SOURCE)
      method = YARD::Registry.at("Sample#call")

      assert_equal SIGNATURE_EXPECTED, Phlex::Shadcn::Llms::Signature.render(method.parameters)
    ensure
      YARD::Registry.clear
    end
  end

  def test_signature_strips_the_delimiters_each_ruby_leaves_on_a_default
    rendered = lambda do |default|
      Phlex::Shadcn::Llms::Signature.render([ [ "width:", default ], [ "**attrs", nil ] ])
    end

    [ "-4", "-4,", "-4)", "-4,)", "-4 ,\n  " ].each { |raw| assert_equal "(width: -4, **attrs)", rendered.call(raw), raw.inspect }
    [ "[1, 2]", "[1, 2])", "[1, 2]," ].each { |raw| assert_equal "(width: [1, 2], **attrs)", rendered.call(raw), raw.inspect }
    assert_equal "(width: %w[a b], **attrs)", rendered.call("%w[a b])")
    assert_equal "(width: foo(1), **attrs)", rendered.call("foo(1))")
    assert_equal "(width: { a: 1, b: 2 }, **attrs)", rendered.call("{ a: 1,\n    b: 2 },")
    assert_equal "(value = -1)", Phlex::Shadcn::Llms::Signature.render([ [ "value", "-1," ] ])
    [ "foo(1)", "Foo.bar(1)", '"a, b)"', "->(x) { x }", '""' ].each do |clean|
      assert_equal "(width: #{clean}, **attrs)", rendered.call(clean), clean.inspect
    end
    assert_equal '(width: "a, b)", **attrs)', rendered.call('"a, b)")')
    assert_equal "(width: ->(x) { x }, **attrs)", rendered.call("->(x) { x })")
    assert_equal "(a, b:)", Phlex::Shadcn::Llms::Signature.render([ [ "a", nil ], [ "b:", nil ] ])
  end

  def test_signature_fails_loud_on_a_default_it_cannot_render
    [ ",", ")", "foo(", "<<~T", "{ a: 1, # note\n b: 2 }" ].each do |raw|
      assert_raises(ArgumentError, raw.inspect) { Phlex::Shadcn::Llms::Signature.render([ [ "width:", raw ] ]) }
    end
  end

  def test_no_generated_file_has_a_doubled_comma
    %w[test/fixtures/public_api.txt llms.txt llms-full.txt skills/phlex-shadcn/SKILL.md].each do |file|
      refute_includes File.read(File.join(GEM_DIR, file), encoding: "UTF-8"), ",,", "#{file} has a doubled comma in a signature"
    end
  end

  def test_llms_txt_follows_the_convention
    lines = File.read(File.join(GEM_DIR, "llms.txt")).lines

    assert_match(/\A# \S/, lines.first)
    assert_match(/\A> \S/, lines[2])
    assert(lines.any? { |line| line.start_with?("## ") })
    assert(lines.grep(/\A- \[/).all? { |line| line.match?(%r{\A- \[[^\]]+\]\(https://[^)]+\)}) })
  end

  def test_changing_a_component_keyword_without_regenerating_fails_the_check
    Dir.mktmpdir("llms-drift") do |dir|
      %w[lib app llms.txt llms-full.txt skills].each { |entry| FileUtils.cp_r(File.join(GEM_DIR, entry), dir) }
      button = File.join(dir, "lib/phlex/shadcn/button.rb")
      source = File.read(button)
      mutated = source.sub("as_child: false, **attrs)\n    @variant", "as_child: false, loading: false, **attrs)\n    @variant")

      refute_equal source, mutated, "the mutation did not apply: update this test to the current Button#initialize"
      File.write(button, mutated)
      out, status = run_cli("check", dir)

      refute_predicate status, :success?, out
      assert_includes out, "llms-full.txt"
    end
  end

  def test_stimulus_values_and_events_are_complete_for_known_controllers
    full = File.read(File.join(GEM_DIR, "llms-full.txt"))
    dialog = full[/^Stimulus: `shadcn--dialog`.*$/]

    %w[open controlled modal id].each { |value| assert_includes dialog, "`#{value}`" }
    %w[open-change escape-key-down pointer-down-outside focus-outside interact-outside].each { |event| assert_includes dialog, "`#{event}`" }
    slider = full[/^Stimulus: `shadcn--slider`.*$/]

    %w[max step min-steps-between-thumbs preserve-thumb-order form].each { |value| assert_includes slider, "`#{value}`" }
    assert_includes full[/^Stimulus: `shadcn--alert-dialog`.*$/], "`open-change`"
    context_menu = full[/^Stimulus: `shadcn--context-menu`.*$/]

    %w[open-change select checked-change value-change escape-key-down close-auto-focus].each { |event| assert_includes context_menu, "`#{event}`" }
  end

  def test_changing_a_stimulus_value_without_regenerating_fails_the_check
    Dir.mktmpdir("llms-drift") do |dir|
      %w[lib app llms.txt llms-full.txt skills].each { |entry| FileUtils.cp_r(File.join(GEM_DIR, entry), dir) }
      js = File.join(dir, "app/javascript/controllers/shadcn/dialog_controller.js")
      source = File.read(js)
      mutated = source.sub("static values = { open: Boolean,", "static values = { open: Boolean, dismissible: Boolean,")

      refute_equal source, mutated, "the mutation did not apply: update this test to the current dialog controller"
      File.write(js, mutated)
      out, status = run_cli("check", dir)

      refute_predicate status, :success?, out
    end
  end

  private

  def run_cli(command, root) = Open3.capture2e(RbConfig.ruby, CLI, command, "--root", root)
end

# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require TOOLING_ROOT.join(".claude/scripts/shadcn/static_gate.rb").to_s

# The G1 static gate (.claude/scripts/shadcn/static_gate.rb): the kwarg check ignores rest props, including the whole-props
# parameter of `function X(props: ...)`, and still flags a genuinely missing kwarg.
class StaticGateTest < ActiveSupport::TestCase
  def manifest(typed)
    {
      "name" => "widget", "parts" => [ { "name" => "Widget", "props" => { "destructured" => [], "typed" => typed.map { |n| { "name" => n } } } } ],
      "cva" => {}, "data_slots" => [], "class_tokens" => [], "data_attrs" => []
    }
  end

  def findings_for(typed, source)
    Dir.mktmpdir do |dir|
      file = File.join(dir, "widget.rb")
      File.write(file, source)
      ShadcnStaticGate::Checker.new(manifest(typed), [ file ], {}).call.select { |f| f.code == "G1_KWARG_MISSING" }
    end
  end

  SOURCE = "class Widget\n  def initialize(**attrs)\n  end\nend\n"

  test "the whole-props parameter is treated as rest" do
    assert_empty findings_for([ "props" ], SOURCE)
  end

  test "a genuinely missing kwarg is still flagged" do
    found = findings_for(%w[props sideOffset], SOURCE)

    assert_equal [ "side_offset" ], found.map(&:expected)
  end
end

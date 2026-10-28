# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "timeout"
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

  def part_findings(source)
    manifest = {
      "name" => "input-otp", "cva" => {}, "data_slots" => [], "class_tokens" => [], "data_attrs" => [],
      "parts" => %w[InputOTP InputOTPGroup].map { |n| { "name" => n, "props" => { "destructured" => [], "typed" => [] } } }
    }
    Dir.mktmpdir do |dir|
      file = File.join(dir, "input_otp.rb")
      File.write(file, source)
      ShadcnStaticGate::Checker.new(manifest, [ file ], {}).call.select { |f| f.code == "G1_PART_MISSING" }
    end
  end

  test "an acronym part resolves to its mixed-case Ruby class" do
    assert_empty part_findings("class Chadcn::InputOtp\n  class Group\n  end\nend\n")
  end

  test "a genuinely missing part is still flagged" do
    assert_equal [ "InputOTPGroup" ], part_findings("class Chadcn::InputOtp\nend\n").map(&:part)
  end

  def parts_findings(manifest, source, code)
    Dir.mktmpdir do |dir|
      file = File.join(dir, "chart.rb")
      File.write(file, source)
      ShadcnStaticGate::Checker.new(manifest, [ file ], {}).call.select { |f| f.code == code }
    end
  end

  def chart_manifest(parts)
    { "name" => "chart", "parts" => parts, "cva" => {}, "data_slots" => [], "class_tokens" => [], "data_attrs" => [] }
  end

  def part(name, destructured = [])
    { "name" => name, "props" => { "destructured" => destructured.map { |n| { "name" => n } }, "typed" => [] } }
  end

  NESTED = <<~RUBY
    class Chart
      class Tooltip
        def content = nil

        class Content
          def initialize(**attrs); end
        end
      end
    end
  RUBY

  test "a nested Tooltip::Content satisfies the oracle part ChartTooltipContent" do
    assert_empty parts_findings(chart_manifest([ part("ChartTooltipContent") ]), NESTED, "G1_PART_MISSING")
  end

  test "the compact Tooltip::Content spelling satisfies it too" do
    source = "class Chart\n  class Tooltip::Content\n  end\nend\n"

    assert_empty parts_findings(chart_manifest([ part("ChartTooltipContent") ]), source, "G1_PART_MISSING")
  end

  test "a missing nested class is still reported" do
    source = "class Chart\n  class Tooltip\n  end\nend\n"
    found = parts_findings(chart_manifest([ part("ChartTooltipContent") ]), source, "G1_PART_MISSING")

    assert_equal [ "ChartTooltipContent" ], found.map(&:part)
  end

  test "an unrelated Content class does not satisfy the nested part" do
    source = "class Chart\n  class Tooltip\n  end\n\n  class Legend\n    class Content\n    end\n  end\nend\n"

    assert_equal [ "ChartTooltipContent" ], parts_findings(chart_manifest([ part("ChartTooltipContent") ]), source, "G1_PART_MISSING").map(&:part)
  end

  test "a grandchild Content two levels below Tooltip does not satisfy the nested part" do
    source = "class Chart\n  class Tooltip\n    class Foo\n      class Content\n      end\n    end\n  end\nend\n"

    assert_equal [ "ChartTooltipContent" ], parts_findings(chart_manifest([ part("ChartTooltipContent") ]), source, "G1_PART_MISSING").map(&:part)
  end

  test "a commented-out nested class does not satisfy the part" do
    source = "class Chart\n  # class Tooltip::Content\n  # end\nend\n"

    assert_equal [ "ChartTooltipContent" ], parts_findings(chart_manifest([ part("ChartTooltipContent") ]), source, "G1_PART_MISSING").map(&:part)
  end

  test "a Content inside Tooltip::Foo does not satisfy the nested part" do
    source = "class Chart\n  class Tooltip::Foo\n    class Content\n    end\n  end\nend\n"

    assert_equal [ "ChartTooltipContent" ], parts_findings(chart_manifest([ part("ChartTooltipContent") ]), source, "G1_PART_MISSING").map(&:part)
  end

  test "a one-line Tooltip does not lend its nesting to a sibling's Content" do
    source = "class Chart\n  class Tooltip < Base; end\n\n  class Legend\n    class Content\n    end\n  end\nend\n"

    assert_equal [ "ChartTooltipContent" ], parts_findings(chart_manifest([ part("ChartTooltipContent") ]), source, "G1_PART_MISSING").map(&:part)
  end

  test "a part with many whitespace-only lines is judged without catastrophic backtracking" do
    source = "class Chart\n  class Tooltip\n#{"    \n" * 40}  end\nend\n"
    found = Timeout.timeout(5) { parts_findings(chart_manifest([ part("ChartTooltipContent") ]), source, "G1_PART_MISSING") }

    assert_equal [ "ChartTooltipContent" ], found.map(&:part)
  end

  test "a Content under another class's Tooltip or below Content does not satisfy the part" do
    manifest = chart_manifest([ part("ChartTooltipContent") ])
    foreign = "class Chart\n  class Legend::Tooltip::Content\n  end\nend\n"
    deeper = "class Chart\n  class Tooltip::Content::Bar\n  end\nend\n"

    assert_equal [ "ChartTooltipContent" ], parts_findings(manifest, foreign, "G1_PART_MISSING").map(&:part)
    assert_equal [ "ChartTooltipContent" ], parts_findings(manifest, deeper, "G1_PART_MISSING").map(&:part)
  end

  test "the fully qualified Chadcn::Chart::Tooltip::Content satisfies the part" do
    source = "module Chadcn\n  class Chart::Tooltip::Content\n  end\nend\n"

    assert_empty parts_findings(chart_manifest([ part("ChartTooltipContent") ]), source, "G1_PART_MISSING")
  end

  test "a commented-out flat class does not satisfy the part" do
    source = "class Chart\n  # class TooltipContent\nend\n"

    assert_equal [ "ChartTooltipContent" ], parts_findings(chart_manifest([ part("ChartTooltipContent") ]), source, "G1_PART_MISSING").map(&:part)
  end

  test "an indented Content::Bar below Tooltip does not satisfy the nested part" do
    source = "class Chart\n  class Tooltip\n    class Content::Bar\n    end\n  end\nend\n"

    assert_equal [ "ChartTooltipContent" ], parts_findings(chart_manifest([ part("ChartTooltipContent") ]), source, "G1_PART_MISSING").map(&:part)
  end

  test "a bare Tooltip::Content outside class Chart does not satisfy the nested part" do
    manifest = chart_manifest([ part("ChartTooltipContent") ])
    inside_legend = "class Chart\nend\n\nclass Legend\n  class Tooltip::Content\n  end\nend\n"
    top_level = "class Chart\nend\n\nclass Tooltip::Content\nend\n"

    assert_equal [ "ChartTooltipContent" ], parts_findings(manifest, inside_legend, "G1_PART_MISSING").map(&:part)
    assert_equal [ "ChartTooltipContent" ], parts_findings(manifest, top_level, "G1_PART_MISSING").map(&:part)
  end

  test "a Tooltip outside class Chart does not lend its Content" do
    source = "class Chart\nend\n\nclass Legend\n  class Tooltip\n    class Content\n    end\n  end\nend\n"

    assert_equal [ "ChartTooltipContent" ], parts_findings(chart_manifest([ part("ChartTooltipContent") ]), source, "G1_PART_MISSING").map(&:part)
  end

  test "a foreign namespace in front of the root does not satisfy the nested part" do
    manifest = chart_manifest([ part("ChartTooltipContent") ])
    one_line = "class Legend::Chart::Tooltip::Content\nend\n"
    nested = "class Legend::Chart\n  class Tooltip\n    class Content\n    end\n  end\nend\n"

    assert_equal [ "ChartTooltipContent" ], parts_findings(manifest, one_line, "G1_PART_MISSING").map(&:part)
    assert_equal [ "ChartTooltipContent" ], parts_findings(manifest, nested, "G1_PART_MISSING").map(&:part)
  end

  test "the legit nested forms also match in a CRLF source" do
    source = "class Chart\r\n\r\n  class Tooltip\r\n\r\n    class Content\r\n    end\r\n  end\r\nend\r\n"

    assert_empty parts_findings(chart_manifest([ part("ChartTooltipContent") ]), source, "G1_PART_MISSING")
  end

  test "the flat form still satisfies the part" do
    source = "class Chart\n  class TooltipContent\n  end\nend\n"

    assert_empty parts_findings(chart_manifest([ part("ChartTooltipContent") ]), source, "G1_PART_MISSING")
  end

  test "the props of a helper function are not kwargs of a part" do
    manifest = chart_manifest([ part("Chart"), part("getPayloadConfigFromPayload", %w[config payload key]) ])
    source = "class Chart\n  def initialize(**attrs); end\nend\n"

    assert_empty parts_findings(manifest, source, "G1_KWARG_MISSING")
  end

  test "a real part missing a kwarg is still reported next to a helper" do
    manifest = chart_manifest([ part("Chart", %w[id]), part("getPayloadConfigFromPayload", %w[config payload key]) ])
    source = "class Chart\n  def initialize(**attrs); end\nend\n"

    assert_equal [ "id" ], parts_findings(manifest, source, "G1_KWARG_MISSING").map(&:expected)
  end
end

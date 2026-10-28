# frozen_string_literal: true

require "chadcn/test_case"

# The chart math is internal: every class, module and public method under lib/chadcn/chart (scale/ and shape/)
# carries `@api private` in its YARD comment, and none of it is in the public API snapshot (test/fixtures/public_api.txt).
class Chadcn::Chart::ApiPrivateTest < Chadcn::TestCase
  ROOT = File.expand_path("../../../..", __dir__)
  FILES = Dir[File.join(ROOT, "lib/chadcn/chart/**/*.rb")].freeze
  # Files of the chart math today; a new file raises it here, so a glob that silently stops matching fails the suite.
  EXPECTED_FILE_COUNT = 30
  DECLARATION = /\A(?<indent>\s*)(?:(?:class|module)\s+(?<constant>[A-Z][\w:]*)|def\s+(?<method>[\w.?!=]+)|attr_(?:reader|accessor|writer)\s+:)/

  test "the files under test are found in every directory" do
    assert_equal EXPECTED_FILE_COUNT, FILES.size, FILES.map { |file| file.delete_prefix("#{ROOT}/") }.join("\n")
    assert_includes FILES.join("\n"), "chart/shape/js_math.rb"
    assert_includes FILES.join("\n"), "chart/scale/linear.rb"
    assert_includes FILES.join("\n"), "chart/shape/curve/monotone_x.rb"
  end

  test "every class, module and public method is documented @api private" do
    undocumented = FILES.flat_map { |file| undocumented_declarations(file) }

    assert_empty undocumented, "missing `@api private` in the YARD comment above:\n#{undocumented.join("\n")}"
  end

  test "no chart math constant is in the public API snapshot" do
    snapshot = File.read(File.join(ROOT, "test/fixtures/public_api.txt"))

    assert_not_includes snapshot, "Chadcn::Chart::Scale"
    assert_not_includes snapshot, "Chadcn::Chart::Shape"
  end

  test "every file defines the constant its path names" do
    FILES.each do |file|
      path = file.delete_prefix("#{File.join(ROOT, 'lib')}/").delete_suffix(".rb")
      name = path.split("/").map { |part| Chadcn::Loader.inflector.camelize(part, file) }.join("::")

      assert Object.const_defined?(name), "#{name} (#{path})"
    end
  end

  private

  # Declarations (outside `private` sections) whose preceding comment block lacks @api private.
  def undocumented_declarations(file)
    lines = File.readlines(file, chomp: true)
    private_indent = nil
    lines.each_with_index.filter_map do |line, index|
      match = DECLARATION.match(line)
      indent = line[/\A\s*/].size
      private_indent = nil if private_indent && indent < private_indent && line.match?(/\A\s*end\b/)
      private_indent = indent if line.match?(/\A\s*private\s*\z/)
      next unless match
      next if private_indent && indent >= private_indent
      next if comment_above(lines, index).include?("@api private")

      "#{file.delete_prefix("#{ROOT}/")}:#{index + 1}: #{line.strip}"
    end
  end

  def comment_above(lines, index)
    block = []
    cursor = index - 1
    cursor -= 1 while cursor >= 0 && lines[cursor].match?(/\A\s*#\s*rubocop:/)
    while cursor >= 0 && lines[cursor].match?(/\A\s*#/)
      block.unshift(lines[cursor])
      cursor -= 1
    end
    block.join("\n")
  end
end

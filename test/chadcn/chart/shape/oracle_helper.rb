# frozen_string_literal: true

require "json"
require "chadcn/test_case"

# Loads the expected values that test/chadcn/chart/shape/oracle.mjs generated from the real d3 and recharts, and compares numbers
# the way those tests need: path strings exactly, number lists to a tiny tolerance with NaN and the infinities spelled as JavaScript
# serializes them ("NaN", "Infinity", "-Infinity" in the JSON; null for an infinite value inside an array).
module ChartOracle
  SCALE_FILE = File.expand_path("../scale/oracle.json", __dir__)
  SHAPE_FILE = File.expand_path("oracle.json", __dir__)
  TOLERANCE = 1e-9

  def self.scale = (@scale ||= deep_freeze(JSON.parse(File.read(SCALE_FILE))))

  def self.shape = (@shape ||= deep_freeze(JSON.parse(File.read(SHAPE_FILE))))

  # The cases of one section of an oracle file (`:scale` or `:shape`). A test that loops over them passes vacuously when the file is
  # regenerated with fewer cases (or an empty section), so every caller names the number of cases committed today.
  def self.cases(source, section, minimum:)
    found = public_send(source).fetch(section)
    raise "oracle #{source}/#{section} has #{found.size} cases, expected at least #{minimum}" if found.size < minimum

    found
  end

  def self.deep_freeze(value)
    case value
    when Hash then value.each_value { |item| deep_freeze(item) }
    when Array then value.each { |item| deep_freeze(item) }
    end
    value.freeze
  end
  private_class_method :deep_freeze

  # "bumpX" -> :bump_x, "linearClosed" -> :linear_closed
  def self.snake(name) = name.to_s.gsub(/([A-Z])/) { "_#{Regexp.last_match(1).downcase}" }.to_sym

  # Keys of a JavaScript options hash as Ruby keywords.
  def self.keywords(hash) = hash.to_h { |key, value| [ snake(key), value ] }

  # Asserts two numbers are equal within TOLERANCE; "NaN", "Infinity" and null (a JSON-serialized non-finite number) match the
  # non-finite Ruby value of the same kind.
  def assert_close(expected, actual, message = nil)
    case expected
    when nil then assert_not_predicate(actual, :finite?, message)
    when "NaN" then assert_predicate(actual, :nan?, message)
    when "Infinity" then assert_equal(Float::INFINITY, actual, message)
    when "-Infinity" then assert_equal(-Float::INFINITY, actual, message)
    else
      assert_in_delta(expected, actual, TOLERANCE, message)
    end
  end

  def assert_all_close(expected, actual, message = nil)
    assert_equal(expected.size, actual.size, "#{message} (size): expected #{expected.inspect}, got #{actual.inspect}")
    expected.zip(actual).each_with_index { |(want, got), index| assert_close(want, got, "#{message} [#{index}]: #{actual.inspect}") }
  end
end

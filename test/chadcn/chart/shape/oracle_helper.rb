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

  def self.scale = (@scale ||= JSON.parse(File.read(SCALE_FILE)))

  def self.shape = (@shape ||= JSON.parse(File.read(SHAPE_FILE)))

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

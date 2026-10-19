# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "phlex/shadcn"
require "minitest/autorun"
require "nokogiri"
require "net/http"

# The suite has no network. An unstubbed Net::HTTP.start is a test bug, reported as a failure that no `rescue` in the code under
# test can swallow (theme_import_test.rb swaps in its scripted stand-in for the duration of each test).
Net::HTTP.define_singleton_method(:start) do |address, *, **|
  raise Minitest::Assertion, "unstubbed Net::HTTP.start(#{address.inspect}): the tests never reach the network"
end

# frozen_string_literal: true

require "json"

module Phlex
  module Shadcn
    module Doctor
      # The results of a doctor run, as text or JSON.
      #
      # @api private
      class Report
        # The statuses a check can end with, in report order.
        STATUSES = %i[pass warn fail].freeze
        LABELS = STATUSES.to_h { |status| [ status, status.to_s.upcase ] }.freeze
        private_constant :LABELS

        # @return [Array<Result>]
        attr_reader :results

        # @param results [Array<Result>]
        def initialize(results) = @results = results

        # @return [Boolean] false when any check failed (warnings do not fail the run)
        def ok? = results.none? { |result| result.status == :fail }

        # @return [Hash{Symbol => Integer}] how many results each status has
        def counts = LABELS.keys.to_h { |status| [ status, results.count { |result| result.status == status } ] }

        # @return [Hash] the JSON shape of the report
        def to_h = { ok: ok?, summary: counts, checks: results.map(&:to_h) }

        # @return [String] the report as JSON, for CI and agents
        def to_json(*) = JSON.pretty_generate(to_h)

        # @return [String] one line per check, a "fix:" line under each warning and failure, and a summary
        def to_text
          lines = results.flat_map do |result|
            line = "[#{LABELS.fetch(result.status)}] #{result.name}: #{result.message}"
            result.fix ? [ line, "       fix: #{result.fix}" ] : [ line ]
          end
          lines << "" << "#{counts[:pass]} passed, #{counts[:warn]} warnings, #{counts[:fail]} failed"
          lines.join("\n")
        end
      end
    end
  end
end

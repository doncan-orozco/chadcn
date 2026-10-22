# frozen_string_literal: true

require "json"

module Chadcn
  module Doctor
    # The results of a doctor run, as text or JSON.
    #
    # @api private
    class Report
      # The statuses a check can end with, in report order.
      STATUSES = %i[pass warn fail].freeze
      LABELS = STATUSES.to_h { |status| [ status, status.to_s.upcase ] }.freeze
      private_constant :LABELS

      # The output formats the rake task accepts as its argument (`chadcn:doctor[json]`); text is the default.
      FORMATS = %w[text json].freeze

      # What the rake task prints, on stderr, when its format argument is not one of {FORMATS}.
      USAGE = "usage: bin/rails chadcn:doctor[#{FORMATS.join('|')}] (JSON=1 selects json, CSS=path names the Tailwind entry file)".freeze

      # The last line of a text report with no warning and no failure (never in the JSON report: CI and agents parse that).
      SUCCESS = "All checks passed. You're in peak condition."

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

      # @return [String] one line per check, a "fix:" line under each warning and failure, a summary and, when nothing warned or
      #   failed, {SUCCESS}
      def to_text
        summary = counts
        lines = results.flat_map do |result|
          line = "[#{LABELS.fetch(result.status)}] #{result.name}: #{result.message}"
          result.fix ? [ line, "       fix: #{result.fix}" ] : [ line ]
        end
        lines << "" << "#{summary[:pass]} passed, #{summary[:warn]} warnings, #{summary[:fail]} failed"
        lines << SUCCESS if summary[:warn].zero? && summary[:fail].zero?
        lines.join("\n")
      end
    end
  end
end

# frozen_string_literal: true

module Phlex
  module Shadcn
    module Doctor
      # The outcome of one check: a status (`:pass`, `:warn` or `:fail`), what was found and, unless it passed, a one-line fix.
      #
      # @api private
      Result = Data.define(:name, :status, :message, :fix) do
        # @param name [String] the check, e.g. "tailwind"
        # @param status [Symbol] `:pass`, `:warn` or `:fail`
        # @param message [String] what was found
        # @param fix [String, nil] the one-line fix
        # @raise [ArgumentError] when the status is not one of the three
        def initialize(name:, status:, message:, fix: nil)
          raise ArgumentError, "unknown status #{status.inspect} (expected :pass, :warn or :fail)" unless Report::STATUSES.include?(status)

          super
        end

        # @param name [String] the check, e.g. "tailwind"
        # @param message [String] what was found
        # @return [Result]
        def self.passed(name, message) = new(name: name, status: :pass, message: message)

        # @param name [String]
        # @param message [String] what is off
        # @param fix [String] the one-line fix
        # @return [Result]
        def self.warning(name, message, fix:) = new(name: name, status: :warn, message: message, fix: fix)

        # @param name [String]
        # @param message [String] what is wrong
        # @param fix [String] the one-line fix
        # @return [Result]
        def self.failure(name, message, fix:) = new(name: name, status: :fail, message: message, fix: fix)

        # @return [Hash] the JSON shape of the result
        def to_h = { name: name, status: status.to_s, message: message, fix: fix }.compact
      end
    end
  end
end

# frozen_string_literal: true

module Chadcn
  # Diagnoses a host app's chadcn setup (`bin/rails chadcn:doctor`): one pass / warn / fail line, with a one-line fix,
  # for each prerequisite. Every check is one file under `doctor/checks/` (a module with `.call(context)` returning a {Result}),
  # discovered by file name, so a new check is a new file and no shared file changes. The doctor reads files and gem versions only
  # and never references the host framework, so it loads without it; the rake task builds the {Context} from the running app.
  #
  # @api private
  module Doctor
    # Directory the checks are discovered in.
    CHECKS_DIR = File.join(__dir__, "doctor/checks").freeze

    # Runs every check against the context.
    #
    # @param context [Context]
    # @return [Report]
    def self.run(context)
      Report.new(check_classes.map { |check| run_check(check, context) })
    end

    # One check; a check that raises (an unreadable or non-UTF-8 file, say) is a failed result naming the exception, so the report
    # still covers every other check.
    #
    # @param check [Module]
    # @param context [Context]
    # @return [Result]
    def self.run_check(check, context)
      check.call(context)
    rescue StandardError => e
      name = check.const_defined?(:NAME, false) ? check::NAME : check.name.split("::").last
      fix = e.is_a?(SystemCallError) || e.is_a?(EncodingError) ? "make the files the check reads readable UTF-8, then run it again" : "report this chadcn doctor bug"
      Result.failure(name, "the check raised #{e.class}: #{e.message}", fix: "#{fix} (#{e.backtrace&.first})")
    end
    private_class_method :run_check

    # The check classes, in file name order (Dir sorts): `doctor/checks/foo_bar.rb` defines `Doctor::Checks::FooBar`.
    #
    # @return [Array<Module>]
    def self.check_classes
      Dir[File.join(CHECKS_DIR, "*.rb")].map do |path|
        Checks.const_get(File.basename(path, ".rb").split("_").map(&:capitalize).join)
      end
    end
  end
end

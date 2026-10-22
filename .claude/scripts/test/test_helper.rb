# frozen_string_literal: true

# Tests of the repository tooling (.claude/scripts: the audit receipt, the epic board, the gem gate). They are not gem tests:
# `rake test:tooling` runs them, `rake test` does not. ActiveSupport::TestCase gives them the `test "..." do` / `setup do` style
# they were written in; activesupport comes with the bundle's engine group.
require "pathname"
require "minitest/autorun"
require "active_support"
require "active_support/test_case"

TOOLING_ROOT = Pathname(File.expand_path("../../..", __dir__))

require_relative "test_helper"
require "tmpdir"
require "open3"
require "rbconfig"
require TOOLING_ROOT.join(".claude/scripts/audit_receipt").to_s

# The receipt is how a script (not an agent's word) decides that an /audit-feature run met the bar for THIS code.
class AuditReceiptTest < ActiveSupport::TestCase
  SCORES = { "architecture" => 9, "clean_code" => 8, "scalability" => 8, "security" => 9, "testability" => 8 }.freeze

  setup do
    @dir = Dir.mktmpdir("audit-receipt")
    @repo = File.join(@dir, "repo")
    system("git", "init", "-q", @repo, exception: true)
    File.write(File.join(@repo, "a.rb"), "puts 1\n")
    @receipt = File.join(@dir, "scorecard.json")
  end

  teardown { FileUtils.remove_entry(@dir) }

  def write(**over)
    AuditReceipt.write(@receipt, scores: SCORES, verdict: "PASS", mandatory_open: 0, iterations: 1, dir: @repo, **over)
  end

  def check(**opts) = AuditReceipt.check(@receipt, dir: @repo, **opts)

  test "a receipt at the bar for the current code passes and summarises itself" do
    write

    assert check["ok"]
    assert_equal "audit min=8 verdict=PASS iterations=1 tree=#{check['summary'][/tree=(\w+)/, 1]}", check["summary"]
  end

  test "each dimension is judged on its own, an average never rescues a weak one" do
    write(scores: SCORES.merge("architecture" => 10, "clean_code" => 10, "security" => 7))

    refute check["ok"]
    assert_equal [ "security=7 is below 8" ], check["reasons"]
  end

  test "the bar is configurable but defaults to 8" do
    write(scores: SCORES.merge("testability" => 7))

    refute check["ok"]
    assert check(min: 7)["ok"]
  end

  test "verdict, open mandatory findings and a missing receipt each fail with their own reason" do
    write(verdict: "NEEDS-REWORK", mandatory_open: 3)

    assert_equal [ "verdict is \"NEEDS-REWORK\", not PASS", "3 mandatory finding(s) still open" ], check["reasons"]
    assert_match(/no receipt/, AuditReceipt.check(File.join(@dir, "nope.json"), dir: @repo)["reasons"].join)
    File.write(@receipt, "{not json")

    assert_match(/not valid JSON/, check["reasons"].join)
  end

  test "writing refuses unknown or missing dimensions" do
    assert_raises(AuditReceipt::Error) { write(scores: SCORES.except("security")) }
    assert_raises(AuditReceipt::Error) { write(scores: SCORES.merge("style" => 9)) }
  end

  test "any edit after the audit makes the receipt stale, committing the audited code does not" do
    write

    assert check["ok"]
    File.write(File.join(@repo, "a.rb"), "puts 2\n")

    assert_match(/stale receipt/, check["reasons"].join)
    write
    system("git", "-C", @repo, "add", "-A", exception: true)
    system("git", "-C", @repo, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "x", exception: true)

    assert check["ok"]
    File.write(File.join(@repo, "new_file.rb"), "# untracked\n")

    refute check["ok"], "an untracked file added after the audit is unaudited code too"
  end

  test "ignored files do not affect the fingerprint" do
    File.write(File.join(@repo, ".gitignore"), "tmp/\n")
    write
    FileUtils.mkdir_p(File.join(@repo, "tmp"))
    File.write(File.join(@repo, "tmp/report.md"), "audit output")

    assert check["ok"]
  end

  test "the command line writes, checks and exits 1 when the bar is missed" do
    script = TOOLING_ROOT.join(".claude/scripts/audit_receipt.rb").to_s
    scores = "architecture=9,clean_code=9,scalability=9,security=9,testability=8"
    _, err, status = Open3.capture3(RbConfig.ruby, script, "write", "--scores", scores, "--verdict", "PASS", "--iterations", "2", "--out", @receipt, "--dir", @repo)

    assert_predicate status, :success?
    out, = Open3.capture3(RbConfig.ruby, script, "check", @receipt, "--dir", @repo)

    assert JSON.parse(out)["ok"]
    _, status = Open3.capture2(RbConfig.ruby, script, "check", @receipt, "--min", "9", "--dir", @repo)

    assert_equal 1, status.exitstatus
  end
end

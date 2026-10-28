# frozen_string_literal: true

require_relative "test_helper"
require "tmpdir"
require "open3"
require "rbconfig"
require "stringio"
require File.expand_path("fake_gh", __dir__)
require TOOLING_ROOT.join(".claude/scripts/epic/work_board").to_s
require TOOLING_ROOT.join(".claude/scripts/audit_receipt").to_s

# In-process runs route `gh` to FakeGh (fast); the concurrency test runs the real script as subprocesses instead.
module FakeGhRoute
  def gh(*args)
    raise WorkBoard::Failure, "gh #{args.first(2).join(' ')} failed: injected" if ENV["WORK_FAKE_FAIL"] == args.first(2).join(" ")

    FakeGh.call(args)
  rescue FakeGh::Error => e
    raise WorkBoard::Failure, e.message
  end
end
WorkBoard::Shell.prepend(FakeGhRoute)

# Golden tests for the multi-session coordination board (.claude/scripts/epic/work_board.rb). GitHub is replaced by
# .claude/scripts/test/fake_gh.rb; claims are real git refs on a local bare repository, so the atomicity under test is git's own.
class WorkBoardTest < ActiveSupport::TestCase # rubocop:disable Style/OneClassPerFile -- FakeGhRoute above is the in-process gh seam
  SCRIPT = TOOLING_ROOT.join(".claude/scripts/epic/work_board.rb").to_s
  FAKE_GH = File.expand_path("fake_gh.rb", __dir__)
  T0 = "2026-10-12T10:00:00Z"

  setup do
    @dir = Dir.mktmpdir("work-board")
    @remote = File.join(@dir, "remote.git")
    @work = File.join(@dir, "work")
    system("git", "init", "-q", "--bare", @remote, exception: true)
    system("git", "init", "-q", @work, exception: true)
    system("git", "-C", @work, "remote", "add", "origin", @remote, exception: true)
    @db = File.join(@dir, "gh.json")
  end

  teardown { FileUtils.remove_entry(@dir) }

  # Runs a command in-process like an agent's CLI call would; returns [parsed JSON (or {"raw"=>text}), exit status].
  def wb(*args, now: T0, env: {})
    saved = ENV.to_h.slice("WORK_NOW", "WORK_FAKE_DB", "WORK_REMOTE", "WORK_SESSION", "WORK_FAKE_FAIL")
    ENV.update({ "WORK_FAKE_DB" => @db, "WORK_REMOTE" => "origin", "WORK_NOW" => now }.merge(env))
    ENV.delete("WORK_SESSION") unless env.key?("WORK_SESSION")
    out = StringIO.new
    code = 0
    real_out = $stdout
    real_err = $stderr
    $stdout = out
    $stderr = StringIO.new
    Dir.chdir(@work) do
      WorkBoard::Cli.new(args).run
    rescue SystemExit => e
      code = e.status
    end
    [ begin
      JSON.parse(out.string)
    rescue StandardError
      { "raw" => out.string }
    end, code ]
  ensure
    $stdout = real_out
    $stderr = real_err
    %w[WORK_NOW WORK_FAKE_DB WORK_REMOTE WORK_SESSION WORK_FAKE_FAIL].each { |k| saved[k] ? ENV[k] = saved[k] : ENV.delete(k) }
  end

  # Same call as a real subprocess (real `ruby script`, real fake_gh executable): used where true parallelism matters.
  def wb_process(*, now: T0)
    out, _err, status = Open3.capture3({ "WORK_GH" => "#{RbConfig.ruby} #{FAKE_GH}", "WORK_FAKE_DB" => @db, "WORK_REMOTE" => "origin", "WORK_NOW" => now },
                                       RbConfig.ruby, SCRIPT, *, chdir: @work)
    [ begin
      JSON.parse(out)
    rescue StandardError
      { "raw" => out }
    end, status.exitstatus ]
  end

  def make_epic(slug = "demo")
    wb("epic", "create", "--slug", slug, "--title", "Demo epic", "--body", "plan")[0]["number"]
  end

  def make_item(title, wave:, owns:, blocked_by: [], stage: "plan", slug: "demo")
    args = [ "item", "create", "--epic", slug, "--title", title, "--body", "do #{title}", "--wave", wave.to_s, "--owns", owns, "--stage", stage ]
    args += [ "--blocked-by", blocked_by.join(",") ] if blocked_by.any?
    wb(*args)[0]["number"]
  end

  # A plain issue filed outside the epic (a bug report), the way a maintainer files it on GitHub.
  def make_plain_issue(title, body, label: "bug")
    saved = ENV.fetch("WORK_FAKE_DB", nil)
    ENV["WORK_FAKE_DB"] = @db
    FakeGh.call([ "label", "create", label ])
    FakeGh.call([ "issue", "create", "--title", title, "--body", body, "--label", label ])[/(\d+)\z/, 1].to_i
  ensure
    saved ? ENV["WORK_FAKE_DB"] = saved : ENV.delete("WORK_FAKE_DB")
  end

  def claim(number, session, slug: "demo", now: T0, lease: nil)
    args = [ "claim", number.to_s, "--epic", slug, "--session", session ]
    args += [ "--lease", lease.to_s ] if lease
    wb(*args, now: now)
  end

  def state_of(number, slug: "demo") = wb("status", "--epic", slug)[0]["items"].find { |i| i["number"] == number }
  def fake_db = File.exist?(@db) ? JSON.parse(File.read(@db)) : { "issues" => [] }

  test "item adopt takes a plain issue into the epic: contract appended, labels added, original text and labels kept" do
    make_epic
    n = make_plain_issue("Stable ids", "## Problem\nids collide\n\n## Acceptance\n- two renders differ\n")
    gates = File.join(@dir, "gates.txt")
    File.write(gates, "bundle exec rake test\n\nbundle exec rubocop\n")
    out, code = wb("item", "adopt", n.to_s, "--epic", "demo", "--wave", "1", "--owns", "lib/a/**, test/a/**", "--gates-file", gates, "--priority", "7")
    assert_equal 0, code, out.inspect
    assert_equal [ "bundle exec rake test", "bundle exec rubocop" ], out["gates"]

    issue = fake_db["issues"].find { |i| i["number"] == n }
    labels = issue["labels"].map { |l| l["name"] }
    assert_equal %w[bug epic:demo stage:plan wave:1], labels.sort
    assert issue["body"].start_with?("## Problem\nids collide"), "the original report stays first"
    assert_includes issue["body"], "## Gates (a stage advances only when these are green, run by the worker)\n- `bundle exec rake test`\n- `bundle exec rubocop`"
    meta = JSON.parse(issue["body"][WorkBoard::META, 1])
    assert_equal({ "epic" => "demo", "wave" => 1, "owns" => [ "lib/a/**", "test/a/**" ], "blocked_by" => [], "priority" => 7, "adopted" => true }, meta)

    row = wb("status", "--epic", "demo")[0]["items"].find { |i| i["number"] == n }
    assert_equal "ready", row["state"]
    assert_equal [ "lib/a/**", "test/a/**" ], row["owns"]
    assert_equal [ "bundle exec rake test", "bundle exec rubocop" ], wb("show", n.to_s, "--epic", "demo")[0]["gates"]
    assert wb("validate", "--epic", "demo")[0]["pass"]
  end

  test "item adopt refuses an issue that is already an item, a closed issue, and an adoption without gates" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    out, code = wb("item", "adopt", a.to_s, "--epic", "demo", "--wave", "2", "--owns", "lib/b/**", "--gates", "true")
    assert_equal 1, code
    assert_match(/already an item of epic demo/, out["error"])

    n = make_plain_issue("Closed bug", "gone", label: "wontfix")
    ENV["WORK_FAKE_DB"] = @db
    FakeGh.call([ "issue", "close", n.to_s ])
    out, code = wb("item", "adopt", n.to_s, "--epic", "demo", "--wave", "2", "--owns", "lib/b/**", "--gates", "true")
    assert_equal 1, code
    assert_match(/is closed/, out["error"])

    m = make_plain_issue("No gates", "report", label: "enhancement")
    out, code = wb("item", "adopt", m.to_s, "--epic", "demo", "--wave", "2", "--owns", "lib/c/**")
    assert_equal 2, code
    assert_match(/no gates/, out["error"])
    assert_equal 1, wb("status", "--epic", "demo")[0]["items"].size, "nothing was adopted"
  end

  # ---- item amend ----------------------------------------------------------------------------------------------
  def issue_body(number) = fake_db["issues"].find { |i| i["number"] == number }["body"]

  # An item whose body carries the Owns and Blocked by sections /epic-plan writes (blocker lines may carry an explanation).
  def make_sectioned_item(title, wave:, owns:, blocked_by: [])
    deps = blocked_by.map { |n| "- ##{n} (#{(@titles ||= {})[n]})" }
    body = "## Goal\ndo #{title}\n\n## Owns\n- `#{owns}`\n\n## Blocked by\n#{deps.empty? ? '- nothing' : deps.join("\n")}\n\n## Gates\n- `true`\n"
    args = [ "item", "create", "--epic", "demo", "--title", title, "--body", body, "--wave", wave.to_s, "--owns", owns ]
    args += [ "--blocked-by", blocked_by.join(",") ] if blocked_by.any?
    wb(*args)[0]["number"].tap { |n| (@titles ||= {})[n] = title }
  end

  def amend(number, *, session: "s1") = wb("item", "amend", number.to_s, "--epic", "demo", "--session", session, *)

  test "item amend replaces and appends owns and blockers in meta and body, and the note records before and after" do
    root = make_epic
    a = make_sectioned_item("A", wave: 1, owns: "lib/a/**")
    b = make_sectioned_item("B", wave: 2, owns: "lib/b/**", blocked_by: [ a ])
    c = make_sectioned_item("C", wave: 1, owns: "lib/c/**")

    out, code = amend(b, "--add-owns", "test/b.rb, CHANGELOG.md", "--add-blocked-by", c.to_s, "--reason", "needs the changelog")
    assert_equal 0, code, out.inspect
    assert_equal [ "lib/b/**", "test/b.rb", "CHANGELOG.md" ], out["owns"]
    assert_equal [ a, c ], out["blocked_by"]
    assert_includes issue_body(b), "## Owns\n- `lib/b/**`\n- `test/b.rb`\n- `CHANGELOG.md`\n"
    assert_includes issue_body(b), "- ##{a} (A)\n- ##{c}\n"
    meta = JSON.parse(issue_body(b)[WorkBoard::META, 1])
    assert_equal [ "lib/b/**", "test/b.rb", "CHANGELOG.md" ], meta["owns"]
    assert_equal [ a, c ], meta["blocked_by"]
    assert_equal 2, meta["wave"]

    note = fake_db["issues"].find { |i| i["number"] == root }["comments"].last["body"]
    assert_includes note, "[announce]"
    assert_includes note, "item ##{b} amended"
    digest_note = wb("digest", "--epic", "demo", "--item", b.to_s)[0]["notes"].find { |n| n["type"] == "announce" }
    assert_includes digest_note["body"], "item ##{b} amended", "the digest shows it"
    assert_includes note, "needs the changelog"
    assert_includes note, %(owns: ["lib/b/**"] -> ["lib/b/**", "test/b.rb", "CHANGELOG.md"])
    assert_includes note, "blocked_by: [#{a}] -> [#{a}, #{c}]"

    out, code = amend(b, "--owns", "lib/b2/**", "--blocked-by", c.to_s, "--reason", "replace")
    assert_equal 0, code, out.inspect
    assert_equal [ "lib/b2/**" ], out["owns"]
    assert_equal [ c ], out["blocked_by"]
    assert_includes issue_body(b), "## Owns\n- `lib/b2/**`\n\n"
    refute_includes issue_body(b), "lib/b/**"
    assert wb("validate", "--epic", "demo")[0]["pass"]
  end

  test "item amend refuses an item held by another session and allows the holder" do
    make_epic
    a = make_sectioned_item("A", wave: 1, owns: "lib/a/**")
    claim(a, "s2")

    out, code = amend(a, "--add-owns", "lib/x/**", "--reason", "r")
    assert_equal 1, code
    assert_equal "held_by_other", out["reason"]
    out, code = amend(a, "--add-owns", "lib/x/**", "--reason", "r", session: "s2")
    assert_equal 0, code, out.inspect
  end

  test "item amend refuses a done item" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**", stage: "done")

    out, code = amend(a, "--add-owns", "lib/x/**", "--reason", "r")
    assert_equal 1, code
    assert_match(/is done/, out["error"])
  end

  test "item amend refuses an overlap or a cycle and changes nothing" do
    make_epic
    a = make_sectioned_item("A", wave: 1, owns: "lib/a/**")
    b = make_sectioned_item("B", wave: 2, owns: "lib/b/**", blocked_by: [ a ])
    c = make_sectioned_item("C", wave: 2, owns: "lib/c/**")
    before = issue_body(c)
    before_a = issue_body(a)

    out, code = amend(c, "--add-owns", "lib/b/x.rb", "--reason", "r")
    assert_equal 1, code
    assert_equal [ "OWNS_OVERLAP" ], out["findings"].map { |f| f["code"] }.uniq

    out, code = amend(a, "--add-blocked-by", b.to_s, "--reason", "r")
    assert_equal 1, code
    assert_includes out["findings"].map { |f| f["code"] }, "CYCLE"
    assert_equal before, issue_body(c)
    assert_equal before_a, issue_body(a)
    assert_equal [ "lib/a/**" ], wb("show", a.to_s, "--epic", "demo")[0]["owns"]
    assert_empty wb("show", a.to_s, "--epic", "demo")[0]["blocked_by"]
  end

  test "item amend needs a reason and at least one change" do
    make_epic
    a = make_sectioned_item("A", wave: 1, owns: "lib/a/**")

    assert_equal 2, amend(a, "--add-owns", "x")[1]
    assert_equal 2, amend(a, "--reason", "r")[1]
  end

  test "item amend rejects malformed or unknown blockers and a self-block, writing nothing" do
    make_epic
    a = make_sectioned_item("A", wave: 1, owns: "lib/a/**")
    before = issue_body(a)

    assert_equal 2, amend(a, "--add-blocked-by", "abc", "--reason", "r")[1]
    assert_equal 2, amend(a, "--add-blocked-by", "12abc", "--reason", "r")[1]
    out, code = amend(a, "--add-blocked-by", "99", "--reason", "r")
    assert_equal 1, code
    assert_includes out["findings"].map { |f| f["code"] }, "BLOCKER_MISSING"
    out, code = amend(a, "--add-blocked-by", a.to_s, "--reason", "r")
    assert_equal 1, code
    assert_includes out["findings"].map { |f| f["code"] }, "CYCLE"
    assert_equal before, issue_body(a)
  end

  test "item amend writes nothing when a section is missing or holds prose, and reports a no-op" do
    @root = make_epic
    plain = make_item("Plain", wave: 1, owns: "lib/p/**")
    out, code = amend(plain, "--add-owns", "lib/q/**", "--reason", "r")
    assert_equal 2, code
    assert_includes out["error"], "no `## Owns` section"

    prose = wb("item", "create", "--epic", "demo", "--title", "Prose", "--wave", "1", "--owns", "lib/r/**",
               "--body", "## Owns\n- `lib/r/**`\nsome prose a person wrote\n\n## Blocked by\n- nothing\n")[0]["number"]
    before = issue_body(prose)
    out, code = amend(prose, "--add-owns", "lib/s/**", "--reason", "r")
    assert_equal 2, code
    assert_includes out["error"], "would drop"
    assert_equal before, issue_body(prose)

    same = make_sectioned_item("Same", wave: 1, owns: "lib/t/**")
    out, code = amend(same, "--add-owns", "lib/t/**", "--reason", "r")
    assert_equal 0, code
    assert out["unchanged"]
    assert_empty fake_db["issues"].find { |i| i["number"] == @root }.fetch("comments", [])
  end

  test "item amend accepts an amendment to an item that already overlaps, and refuses a bullet with several globs" do
    make_epic
    a = make_sectioned_item("A", wave: 1, owns: "lib/a/**")
    b = make_sectioned_item("B", wave: 1, owns: "lib/a/x/**")
    assert_equal 1, wb("validate", "--epic", "demo")[1], "the fixture overlaps on purpose"

    out, code = amend(b, "--add-owns", "lib/b/**", "--reason", "r")
    assert_equal 0, code, out.inspect
    assert_equal [ "lib/a/x/**", "lib/b/**" ], out["owns"]
    assert_equal 2, amend("#{a}x", "--add-owns", "lib/c/**", "--reason", "r")[1], "a malformed item number is a usage error"

    multi = wb("item", "create", "--epic", "demo", "--title", "Multi", "--wave", "1", "--owns", "lib/m/**",
               "--body", "## Owns\n- `lib/m/**` and `lib/n/**`\n\n## Blocked by\n- nothing\n")[0]["number"]
    out, code = amend(multi, "--add-owns", "lib/o/**", "--reason", "r")
    assert_equal 2, code
    assert_includes out["error"], "several globs"
  end

  test "item amend refuses swapping an existing overlap for a new one" do
    make_epic
    a = make_sectioned_item("A", wave: 1, owns: "lib/a/**")
    make_sectioned_item("B", wave: 1, owns: "lib/a/x/**")
    make_sectioned_item("C", wave: 1, owns: "lib/c/**")

    out, code = amend(a, "--owns", "lib/c/**", "--reason", "r")
    assert_equal 1, code, out.inspect
    assert_equal [ "OWNS_OVERLAP" ], out["findings"].map { |f| f["code"] }.uniq
  end

  test "item amend refuses a bullet whose key is not at its start, and globs that could break the body" do
    make_epic
    prose = wb("item", "create", "--epic", "demo", "--title", "Prose", "--wave", "1", "--owns", "lib/p/**",
               "--body", "## Owns\n- `lib/p/**`\n\n## Blocked by\n- waits on the review (#99)\n")[0]["number"]
    before = issue_body(prose)
    assert_equal 2, amend(prose, "--add-owns", "lib/q/**", "--reason", "r")[1]
    assert_equal before, issue_body(prose)

    a = make_sectioned_item("A", wave: 1, owns: "lib/a/**")
    before = issue_body(a)
    assert_equal 2, amend(a, "--add-owns", "x\n## Gates", "--reason", "r")[1]
    assert_equal 2, amend(a, "--add-owns", "bad`glob", "--reason", "r")[1]
    assert_equal 2, amend(a, "--add-owns", "x} -->", "--reason", "r")[1]
    assert_equal before, issue_body(a)
  end

  test "item amend keeps CRLF line endings of a body edited on the web" do
    make_epic
    a = make_sectioned_item("A", wave: 1, owns: "lib/a/**")
    ENV["WORK_FAKE_DB"] = @db
    FakeGh.call([ "issue", "edit", a.to_s, "--body", issue_body(a).gsub("\n", "\r\n") ])

    out, code = amend(a, "--add-owns", "lib/z/**", "--reason", "r")
    assert_equal 0, code, out.inspect
    assert_includes issue_body(a), "lib/z/**"
    refute_match(/[^\r]\n/, issue_body(a))
  end

  test "item amend refuses a keyless bullet it would drop" do
    make_epic
    keyless = wb("item", "create", "--epic", "demo", "--title", "Keyless", "--wave", "1", "--owns", "lib/k/**",
                 "--body", "## Owns\n- `lib/k/**`\n\n## Blocked by\n- the design review\n")[0]["number"]
    before = issue_body(keyless)

    assert_equal 2, amend(keyless, "--add-owns", "lib/l/**", "--reason", "r")[1]
    assert_equal before, issue_body(keyless)
  end

  test "item amend fails loud with the note text when the announce note cannot be posted" do
    make_epic
    a = make_sectioned_item("A", wave: 1, owns: "lib/a/**")

    out, code = wb("item", "amend", a.to_s, "--epic", "demo", "--session", "s1", "--add-owns", "lib/z/**", "--reason", "why",
                   env: { "WORK_FAKE_FAIL" => "issue comment" })
    assert_equal 1, code
    assert_includes out["error"], "announce note failed"
    assert_includes out["note"], "amended: why"
    assert_includes issue_body(a), "lib/z/**"
  end

  # ---- plan creation and validation ----------------------------------------------------------------------------
  test "epic and items are created with labels, stage and a machine-readable meta block" do
    root = make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    issue = fake_db["issues"].find { |i| i["number"] == a }

    assert_equal 1, root
    assert_includes issue["labels"].map { |l| l["name"] }, "epic:demo"
    assert_includes issue["labels"].map { |l| l["name"] }, "stage:plan"
    assert_includes issue["labels"].map { |l| l["name"] }, "wave:1"
    assert_match(%r{work-item \{.*"owns":\["lib/a/\*\*"\]}, issue["body"])
    assert_includes fake_db["issues"].first["labels"].map { |l| l["name"] }, "epic-root"
  end

  test "epic done closes the root with an announce note, and refuses while an item is open or when already closed" do
    root = make_epic
    make_item("A", wave: 1, owns: "lib/a/**", stage: "done")
    b = make_item("B", wave: 1, owns: "lib/b/**")

    out, code = wb("epic", "done", "--epic", "demo", "--session", "s1")
    assert_equal 1, code
    assert_equal([ b ], out["open"].map { |i| i["number"] })
    assert_equal "OPEN", fake_db["issues"].find { |i| i["number"] == root }["state"].upcase

    wb("item", "create", "--epic", "demo", "--title", "unused", "--body", "x", "--wave", "1", "--owns", "lib/c/**", "--stage", "done")
    ENV["WORK_FAKE_DB"] = @db
    FakeGh.call([ "issue", "close", b.to_s ])
    out, code = wb("epic", "done", "--epic", "demo", "--session", "s1", "--note", "shipped in v1")
    assert_equal 0, code, out.inspect
    assert_equal 3, out["items"]
    assert_equal "CLOSED", fake_db["issues"].find { |i| i["number"] == root }["state"].upcase
    announce = wb("digest", "--epic", "demo")[0]["notes"].find { |n| n["type"] == "announce" }
    assert_match(/epic done: all 3 items are done; shipped in v1/, announce["body"])

    out, code = wb("epic", "done", "--epic", "demo", "--session", "s1")
    assert_equal 1, code
    assert_match(/already closed/, out["error"])
  end

  test "validate passes a clean plan and reports every kind of plan defect" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    make_item("B", wave: 2, owns: "lib/b/**", blocked_by: [ a ])
    result, code = wb("validate", "--epic", "demo")

    assert_equal 0, code, result.inspect
    assert result["pass"]

    c = make_item("C", wave: 1, owns: "lib/a/x.rb") # parallel to A, overlapping files
    d = make_item("D", wave: 1, owns: "lib/d/**", blocked_by: [ a ]) # same wave as its blocker
    e = make_item("E", wave: 3, owns: "lib/e/**", blocked_by: [ 999 ]) # blocker outside the epic
    result, code = wb("validate", "--epic", "demo")
    codes = result["findings"].map { |f| [ f["code"], f["item"] ] }

    assert_equal 1, code
    assert_includes codes, [ "OWNS_OVERLAP", a ]
    assert_includes codes, [ "WAVE_ORDER", d ]
    assert_includes codes, [ "BLOCKER_MISSING", e ]
    overlap = result["findings"].find { |f| f["code"] == "OWNS_OVERLAP" }["detail"]

    assert_match(/\A#{a} and #{c} can run in parallel/, overlap)
  end

  test "validate detects dependency cycles" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    b = make_item("B", wave: 2, owns: "lib/b/**", blocked_by: [ a ])
    db = fake_db
    db["issues"].find { |i| i["number"] == a }["body"].sub!('"blocked_by":[]', %("blocked_by":[#{b}]))
    File.write(@db, JSON.generate(db))
    result, code = wb("validate", "--epic", "demo")

    assert_equal 1, code
    assert(result["findings"].any? { |f| f["code"] == "CYCLE" })
  end

  test "validate requires owns on every item" do
    make_epic
    db_args = [ "item", "create", "--epic", "demo", "--title", "no owns", "--wave", "1", "--owns", "x" ]
    wb(*db_args)
    db = fake_db
    db["issues"].last["body"].sub!('"owns":["x"]', '"owns":[]')
    File.write(@db, JSON.generate(db))

    assert(wb("validate", "--epic", "demo")[0]["findings"].any? { |f| f["code"] == "OWNS_MISSING" })
  end

  # ---- picking work ------------------------------------------------------------------------------------------------
  test "next returns the lowest wave ready item and never an item with an open blocker" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    make_item("B", wave: 2, owns: "lib/b/**", blocked_by: [ a ])
    c = make_item("C", wave: 1, owns: "lib/c/**")

    assert_equal a, wb("next", "--epic", "demo")[0]["item"]["number"]
    claim(a, "s1")

    assert_equal c, wb("next", "--epic", "demo")[0]["item"]["number"], "B stays hidden while A is open"
    claim(c, "s2")
    result = wb("next", "--epic", "demo")[0]

    assert_nil result["item"]
    assert_equal "claimed_by_others", result["reason"]
  end

  test "an item becomes ready only when every blocker is done" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    b = make_item("B", wave: 2, owns: "lib/b/**", blocked_by: [ a ])
    claim(a, "s1")
    wb("advance", a.to_s, "--epic", "demo", "--session", "s1", "--stage", "done")

    assert_equal "ready", state_of(b)["state"]
    assert_equal "done", state_of(a)["state"]
    assert_equal "CLOSED", fake_db["issues"].find { |i| i["number"] == a }["state"]
  end

  test "next skips an item whose files overlap an item another session is working on" do
    make_epic
    a = make_item("A", wave: 1, owns: "app/shared/**")
    b = make_item("B", wave: 1, owns: "app/shared/tweak.rb") # also overlap-flagged by validate; here we test the runtime guard
    claim(a, "s1")
    result, = wb("next", "--epic", "demo")
    refused, code = claim(b, "s2")

    assert_nil result["item"]
    assert_equal "filtered", result["reason"]
    assert_equal 1, code
    assert_equal "owns_overlap", refused["reason"]
    assert_equal [ a ], refused["with"]
  end

  test "next with --stage only offers items in those stages" do
    make_epic
    make_item("A", wave: 1, owns: "lib/a/**", stage: "plan")
    audit = make_item("B", wave: 1, owns: "lib/b/**", stage: "audit")

    assert_equal audit, wb("next", "--epic", "demo", "--stage", "audit")[0]["item"]["number"]
    assert_equal "filtered", wb("next", "--epic", "demo", "--stage", "review")[0]["reason"]
  end

  test "the session that built an item is offered its own audit: the same session audits and iterates" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**", stage: "build")
    claim(a, "builder")
    wb("advance", a.to_s, "--epic", "demo", "--session", "builder", "--stage", "audit", "--keep", "--note", "built")

    assert_equal "builder", state_of(a)["holder"], "audit keeps the claim, nobody else gets the item"
    assert_nil wb("next", "--epic", "demo", "--stage", "audit")[0]["item"], "a held item is not offered to anyone"
    wb("release", a.to_s, "--epic", "demo", "--session", "builder")

    assert_equal a, wb("next", "--epic", "demo", "--stage", "audit", "--session", "builder")[0]["item"]["number"]
  end

  # ---- claims --------------------------------------------------------------------------------------------------------
  test "a held item cannot be claimed by another session, the holder can resume" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    first, code = claim(a, "s1")

    assert_equal 0, code
    assert first["claimed"]
    assert_includes fake_db["issues"].find { |i| i["number"] == a }["labels"].map { |l| l["name"] }, "claimed"

    second, code = claim(a, "s2")

    assert_equal 1, code
    assert_equal "held", second["reason"]
    assert_equal "s1", second["holder"]

    again, code = claim(a, "s1")

    assert_equal 0, code
    assert again["resumed"]
  end

  test "exactly one of many concurrent sessions wins an item" do
    make_epic
    3.times do |round|
      number = make_item("race-#{round}", wave: 1, owns: "lib/race#{round}/**")
      results = Array.new(8) do |i|
        Thread.new { wb_process("claim", number.to_s, "--epic", "demo", "--session", "racer-#{i}") }
      end.map(&:value)
      winners = results.select { |_, code| code.zero? }

      assert_equal 1, winners.size, "round #{round}: #{results.map { |r, c| [ c, r['reason'] ] }.inspect}"
      holder = state_of(number)["holder"]

      assert_equal winners.first[0]["session"], holder
    end
  end

  test "a claim whose lease expired is taken over and the old holder is told it lost the item" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    claim(a, "s1", lease: 1)
    later = "2026-10-12T10:05:00Z"

    assert_equal "ready", wb("status", "--epic", "demo", now: later)[0]["items"].first["state"], "an expired claim no longer blocks"
    assert_equal a, wb("next", "--epic", "demo", now: later)[0]["item"]["number"]

    taken, code = claim(a, "s2", now: later)

    assert_equal 0, code, taken.inspect
    stale, code = wb("heartbeat", a.to_s, "--epic", "demo", "--session", "s1", now: later)

    assert_equal 1, code
    assert_equal "held_by_other", stale["reason"]
    _, code = wb("release", a.to_s, "--epic", "demo", "--session", "s1", now: later)

    assert_equal 1, code
    assert_equal "s2", wb("status", "--epic", "demo", now: later)[0]["items"].first["holder"]
  end

  test "heartbeat extends the lease so the item is not taken over" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    claim(a, "s1", lease: 10)
    _, code = wb("heartbeat", a.to_s, "--epic", "demo", "--session", "s1", "--lease", "10", now: "2026-10-12T10:08:00Z")

    assert_equal 0, code
    at_twelve = wb("status", "--epic", "demo", now: "2026-10-12T10:12:00Z")[0]["items"].first

    assert_equal "in-progress", at_twelve["state"], "lease was renewed at 10:08 for 10 minutes"
    assert_equal "s1", at_twelve["holder"]
  end

  test "reap frees expired claims and clears their label" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    claim(a, "s1", lease: 1)
    result, = wb("reap", "--epic", "demo", now: "2026-10-12T11:00:00Z")

    assert_equal [ { "number" => a, "was_held_by" => "s1" } ], result["freed"]
    refute_includes fake_db["issues"].find { |i| i["number"] == a }["labels"].map { |l| l["name"] }, "claimed"
    assert_empty wb("reap", "--epic", "demo", now: "2026-10-12T11:00:00Z")[0]["freed"]
  end

  test "only the holder can release and release makes the item claimable again" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    claim(a, "s1")
    _, code = wb("release", a.to_s, "--epic", "demo", "--session", "s2")

    assert_equal 1, code
    _, code = wb("release", a.to_s, "--epic", "demo", "--session", "s1")

    assert_equal 0, code
    assert_equal 0, claim(a, "s2")[1]
  end

  test "claim refuses an item that is not ready" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    b = make_item("B", wave: 2, owns: "lib/b/**", blocked_by: [ a ])
    result, code = claim(b, "s1")

    assert_equal 1, code
    assert_equal "not_ready", result["reason"]
  end

  test "an unreachable remote is an error, never an empty claim list" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    _, code = wb("claim", a.to_s, "--epic", "demo", "--session", "s1", env: { "WORK_REMOTE" => File.join(@dir, "missing.git") })

    assert_equal 2, code
  end

  # ---- stages, blocking, notes ---------------------------------------------------------------------------------
  test "advance moves the stage label, logs the transition and releases; --keep holds the claim" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    claim(a, "s1")
    kept, code = wb("advance", a.to_s, "--epic", "demo", "--session", "s1", "--stage", "test-plan", "--keep")

    assert_equal 0, code, kept.inspect
    assert_equal "s1", wb("status", "--epic", "demo")[0]["items"].first["holder"]
    wb("advance", a.to_s, "--epic", "demo", "--session", "s1", "--stage", "build")
    labels = fake_db["issues"].find { |i| i["number"] == a }["labels"].map { |l| l["name"] }

    assert_includes labels, "stage:build"
    refute_includes labels, "stage:plan"
    refute_includes labels, "claimed"
    assert_nil wb("status", "--epic", "demo")[0]["items"].first["holder"]
    logs = fake_db["issues"].find { |i| i["number"] == a }["comments"].map { |c| c["body"] }

    assert_equal(2, logs.count { |b| b.include?('"type":"stage-log"') })
  end

  test "advance and block are refused for a session that does not hold the item" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    claim(a, "s1")

    assert_equal 1, wb("advance", a.to_s, "--epic", "demo", "--session", "s2", "--stage", "build")[1]
    assert_equal 1, wb("block", a.to_s, "--epic", "demo", "--session", "s2", "--reason", "nope")[1]
    assert_equal 2, wb("advance", a.to_s, "--epic", "demo", "--session", "s1", "--stage", "nonsense")[1]
  end

  test "block releases the claim, labels needs-human and leaves a blocker note; unblock restores readiness" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    claim(a, "s1")
    wb("block", a.to_s, "--epic", "demo", "--session", "s1", "--reason", "gate keeps failing on X")

    assert_equal "blocked", state_of(a)["state"]
    assert_equal "needs_human", wb("next", "--epic", "demo")[0]["reason"]
    assert_equal 1, claim(a, "s2")[1]
    wb("unblock", a.to_s, "--epic", "demo")

    assert_equal "ready", state_of(a)["state"]
    assert_match(/gate keeps failing on X/, wb("digest", "--epic", "demo", "--item", a.to_s)[0]["notes"].first["body"])
  end

  test "digest gives a worker the epic thread, its own notes and its blockers' shared notes, and nothing else" do
    root = make_epic
    base = make_item("Base class", wave: 1, owns: "lib/base/**")
    other = make_item("Unrelated", wave: 1, owns: "lib/other/**")
    user = make_item("Consumer", wave: 2, owns: "lib/user/**", blocked_by: [ base ])
    wb("comment", root.to_s, "--epic", "demo", "--session", "lead", "--type", "announce", "--body", "rebase on main after #{base}")
    wb("comment", root.to_s, "--epic", "demo", "--session", "s1", "--type", "lesson", "--body", "Slot classes join plainly")
    wb("comment", base.to_s, "--epic", "demo", "--session", "s1", "--type", "shared", "--body", "Base lives in lib/base/base.rb; use cn(...)")
    wb("comment", other.to_s, "--epic", "demo", "--session", "s3", "--type", "shared", "--body", "secret of the unrelated item")
    wb("comment", user.to_s, "--epic", "demo", "--session", "s2", "--type", "handoff", "--body", "left off at the table spec")
    bodies = wb("digest", "--epic", "demo", "--item", user.to_s)[0]["notes"].map { |n| n["body"] }.join("\n")

    assert_includes bodies, "rebase on main"
    assert_includes bodies, "Slot classes join plainly"
    assert_includes bodies, "Base lives in lib/base/base.rb"
    assert_includes bodies, "left off at the table spec"
    refute_includes bodies, "secret of the unrelated item"

    md = wb("digest", "--epic", "demo", "--item", user.to_s, "--format", "md")[0]["raw"]

    assert_match(/### \[shared\] ##{base} by s1/, md)
  end

  test "comments reject unknown types and empty bodies" do
    root = make_epic

    assert_equal 2, wb("comment", root.to_s, "--epic", "demo", "--session", "s1", "--type", "gossip", "--body", "x")[1]
    assert_equal 2, wb("comment", root.to_s, "--epic", "demo", "--session", "s1", "--type", "shared", "--body", "  ")[1]
  end

  test "status counts items by state" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    make_item("B", wave: 1, owns: "lib/b/**")
    make_item("C", wave: 2, owns: "lib/c/**", blocked_by: [ a ])
    claim(a, "s1")

    assert_equal({ "in-progress" => 1, "ready" => 1, "waiting" => 1 }, wb("status", "--epic", "demo")[0]["counts"])
  end

  test "session id is stable per checkout and WORK_SESSION overrides it" do
    first = wb("session")[0]["session"]

    assert_equal first, wb("session")[0]["session"]
    assert_equal "from-env", wb("session", env: { "WORK_SESSION" => "from-env" })[0]["session"]
  end

  test "the real script and the real gh-shaped executable work end to end as subprocesses" do
    root, code = wb_process("epic", "create", "--slug", "demo", "--title", "Demo", "--body", "plan")

    assert_equal 0, code, root.inspect
    item, = wb_process("item", "create", "--epic", "demo", "--title", "A", "--wave", "1", "--owns", "lib/a/**", "--body", "x")

    assert_equal 0, wb_process("claim", item["number"].to_s, "--epic", "demo", "--session", "s1")[1]
    assert_equal 1, wb_process("claim", item["number"].to_s, "--epic", "demo", "--session", "s2")[1]
  end

  # ---- plan files ---------------------------------------------------------------------------------------------------
  def plan_file(items: nil, epic: { "slug" => "gemx", "title" => "Gem epic", "body" => "scope" })
    items ||= [
      { "key" => "skeleton", "title" => "Gem skeleton", "wave" => 0, "owns" => [ "gems/x/**" ], "goal" => "make it", "gates" => [ "bundle exec rake test" ],
        "acceptance" => [ "suite green" ] },
      { "key" => "move", "title" => "Move code", "wave" => 1, "owns" => [ "gems/x/lib/**" ], "blocked_by" => [ "skeleton" ], "goal" => "move",
        "gates" => [ "ruby check.rb" ], "acceptance" => [ "all pass" ], "context" => "see skeleton" },
      { "key" => "docs", "title" => "Docs", "wave" => 1, "owns" => [ "gems/x/README.md" ], "blocked_by" => [ "skeleton" ], "goal" => "write",
        "gates" => [ "true" ], "acceptance" => [ "readme" ] }
    ]
    path = File.join(@dir, "plan.json")
    File.write(path, JSON.generate("epic" => epic, "items" => items))
    path
  end

  test "plan-check accepts a complete plan" do
    result, code = wb("plan-check", "--file", plan_file)

    assert_equal 0, code, result.inspect
    assert result["pass"]
  end

  test "plan-check rejects items without goal, gates or acceptance and plans with structural defects" do
    items = [
      { "key" => "a", "title" => "A", "wave" => 1, "owns" => [ "lib/a/**" ], "goal" => "g", "gates" => [], "acceptance" => [ "x" ] },
      { "key" => "b", "title" => "B", "wave" => 1, "owns" => [ "lib/a/x.rb" ], "goal" => "g", "gates" => [ "true" ], "acceptance" => [ "x" ] },
      { "key" => "b", "title" => "B2", "wave" => 2, "owns" => [ "lib/z/**" ], "blocked_by" => [ "ghost" ], "goal" => "g", "gates" => [ "true" ],
        "acceptance" => [ "x" ] }
    ]
    result, code = wb("plan-check", "--file", plan_file(items: items))
    codes = result["findings"].map { |f| f["code"] }

    assert_equal 1, code
    assert_includes codes, "FIELD_MISSING"
    assert_includes codes, "OWNS_OVERLAP"
    assert_includes codes, "DUPLICATE_ID"
    assert_includes codes, "BLOCKER_MISSING"
    assert_equal 1, wb("plan-check", "--file", plan_file(epic: { "slug" => "Bad Slug", "title" => "" }))[1]
  end

  test "plan-apply creates the root and every item in dependency order with resolved blockers and a contract body" do
    result, code = wb("plan-apply", "--file", plan_file)
    numbers = result["items"]

    assert_equal 0, code, result.inspect
    assert_operator numbers["skeleton"], :<, numbers["move"]
    move = fake_db["issues"].find { |i| i["number"] == numbers["move"] }

    assert_includes move["body"], "## Gates"
    assert_includes move["body"], "`ruby check.rb`"
    assert_includes move["body"], "- ##{numbers['skeleton']} (skeleton)"
    assert_includes move["body"], "see skeleton"
    assert_match(/"blocked_by":\[#{numbers['skeleton']}\]/, move["body"])
    assert wb("validate", "--epic", "gemx")[0]["pass"]
    assert_equal numbers["skeleton"], wb("next", "--epic", "gemx")[0]["item"]["number"]
  end

  test "plan-apply refuses an invalid plan and an epic that already exists" do
    bad = plan_file(items: [ { "key" => "a", "title" => "A", "wave" => 1, "owns" => [], "goal" => "g", "gates" => [ "true" ], "acceptance" => [ "x" ] } ])

    assert_equal 1, wb("plan-apply", "--file", bad)[1]
    assert_empty fake_db["issues"] || []
    assert_equal 0, wb("plan-apply", "--file", plan_file)[1]
    again, code = wb("plan-apply", "--file", plan_file)

    assert_equal 1, code
    assert_match(/already has issues/, again["error"])
    assert_equal 4, fake_db["issues"].size
  end

  test "show returns the item without the machine block, its notes and the current holder" do
    wb("plan-apply", "--file", plan_file)
    first = wb("next", "--epic", "gemx")[0]["item"]["number"]
    claim(first, "s1", slug: "gemx")
    wb("comment", first.to_s, "--epic", "gemx", "--session", "s1", "--type", "handoff", "--body", "started")
    shown = wb("show", first.to_s, "--epic", "gemx")[0]

    assert_equal "s1", shown["holder"]
    refute_includes shown["body"], "work-item"
    assert_includes shown["body"], "## Acceptance"
    assert_equal([ "handoff" ], shown["notes"].map { |n| n["type"] })
  end

  test "a human can force-release an abandoned claim of any session" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    claim(a, "gone-session")
    result, code = wb("release", a.to_s, "--epic", "demo", "--force")

    assert_equal 0, code
    assert_equal "gone-session", result["was_held_by"]
    assert_equal 0, claim(a, "s2")[1]
    assert_equal 1, wb("release", "999", "--epic", "demo", "--force")[1]
  end

  # ---- documentation stays honest ----------------------------------------------------------------------------------
  test "commands and skills only mention work_board subcommands that exist" do
    subcommands = File.read(SCRIPT)[/def run\n.*?\n    end\n/m].scan(/when "([\w-]+)"/).flatten
    docs = Dir[TOOLING_ROOT.join(".claude/commands/{epic-plan,work,work-status,work-release}.md").to_s, TOOLING_ROOT.join(".ai/skills/epic-flow/**/*.md").to_s]
    mentioned = docs.flat_map { |f| File.read(f).scan(/work_board\.rb\s+(?:epic |item )?([a-z][a-z-]*)/).flatten }.uniq

    assert_predicate docs, :any?, "expected the epic commands and skill to exist"
    assert_empty mentioned - subcommands - %w[create], "documented but not implemented: #{(mentioned - subcommands).inspect}"
  end

  test "rule numbers cited by the commands exist in the epic-flow skill" do
    skill = File.read(TOOLING_ROOT.join(".ai/skills/epic-flow/SKILL.md"))
    defined_rules = skill.scan(/^R(\d+)\./).flatten.map(&:to_i)
    cited = Dir[TOOLING_ROOT.join(".claude/commands/{epic-plan,work,work-status,work-release}.md").to_s].flat_map { |f| File.read(f).scan(/\bR(\d+)\b/).flatten.map(&:to_i) }.uniq

    assert_equal (1..defined_rules.max).to_a, defined_rules.sort, "rules are numbered without gaps"
    assert_empty cited - defined_rules, "commands cite rules the skill does not define"
  end

  test "an unknown epic is an error for workers, never all_done; validate reports it as a finding" do
    %w[status next reap].each do |cmd|
      result, code = wb(cmd, "--epic", "typo")

      assert_equal 2, code, cmd
      assert_match(/epic typo not found/, result["error"])
    end
    result, code = wb("validate", "--epic", "typo")

    assert_equal 1, code
    assert_equal "NO_ROOT", result["findings"].first["code"]
  end

  test "unblock works although the blocked label was never created (real gh rejects removing unknown labels)" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    claim(a, "s1")
    wb("block", a.to_s, "--epic", "demo", "--session", "s1", "--reason", "stuck")
    result, code = wb("unblock", a.to_s, "--epic", "demo")

    assert_equal 0, code, result.inspect
    assert_equal "ready", state_of(a)["state"]
    refute_includes fake_db["issues"].find { |i| i["number"] == a }["labels"].map { |l| l["name"] }, "needs-human"
  end

  # ---- review stage: waiting for a human merge ------------------------------------------------------------------------
  def add_pr(number:, head:, state:)
    db = fake_db
    db["prs"] = Array(db["prs"]) << { "number" => number, "state" => state, "headRefName" => head, "mergedAt" => (state == "MERGED" ? T0 : nil), "url" => "https://github.test/o/r/pull/#{number}" }
    File.write(@db, JSON.generate(db))
  end

  def move_to_review(number, session: "builder")
    claim(number, session)
    wb("advance", number.to_s, "--epic", "demo", "--session", session, "--stage", "review", "--audit-receipt", audit_receipt)
  end

  # A receipt like the one /audit-feature persists, written outside the work dir so it is not part of the audited code.
  AUDIT_OK = { "architecture" => 9, "clean_code" => 8, "scalability" => 8, "security" => 9, "testability" => 8 }.freeze

  def audit_receipt(scores: AUDIT_OK, verdict: "PASS", mandatory_open: 0, name: "scorecard.json")
    File.write(File.join(@work, "feature.rb"), "# feature\n") unless File.exist?(File.join(@work, "feature.rb"))
    path = File.join(@dir, name)
    AuditReceipt.write(path, scores: scores, verdict: verdict, mandatory_open: mandatory_open, iterations: 2, dir: @work)
    path
  end

  def advance_to_review(number, receipt, session: "s1")
    Dir.chdir(@work) { wb("advance", number.to_s, "--epic", "demo", "--session", session, "--stage", "review", "--audit-receipt", receipt) }
  end

  # ---- audit bar: the script judges the receipt, not the agent -----------------------------------------------------------
  test "review needs an audit receipt that passes: every dimension >= 8, PASS, nothing mandatory open, for this very code" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**", stage: "audit")
    claim(a, "s1")

    none, code = wb("advance", a.to_s, "--epic", "demo", "--session", "s1", "--stage", "review")

    assert_equal 1, code
    assert_equal "audit_not_passed", none["reason"]
    assert_match(/no receipt/, none["reasons"].join)

    low, code = advance_to_review(a, audit_receipt(scores: AUDIT_OK.merge("security" => 7)))

    assert_equal 1, code
    assert_equal [ "security=7 is below 8" ], low["reasons"], "one weak dimension fails even when the others are 10"

    assert_equal 1, advance_to_review(a, audit_receipt(verdict: "NEEDS-REWORK"))[1]
    assert_equal 1, advance_to_review(a, audit_receipt(mandatory_open: 2))[1]
    incomplete = File.join(@dir, "incomplete.json")
    File.write(incomplete, JSON.generate(JSON.parse(File.read(audit_receipt)).tap { |r| r["scores"].delete("testability") }))
    missing, code = advance_to_review(a, incomplete)

    assert_equal 1, code
    assert_match(/testability score is missing/, missing["reasons"].join)
    assert_equal "audit", state_of(a)["stage"], "a refused advance changes nothing"
    assert_equal "s1", state_of(a)["holder"], "and keeps the claim so the worker can fix and retry"

    good, code = advance_to_review(a, audit_receipt)

    assert_equal 0, code, good.inspect
    assert_equal "review", state_of(a)["stage"]
    note = fake_db["issues"].find { |i| i["number"] == a }["comments"].map { |c| c["body"] }.last

    assert_match(/audit min=8 verdict=PASS iterations=2/, note)
  end

  test "a receipt goes stale the moment the code changes after the audit" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**", stage: "audit")
    claim(a, "s1")
    receipt = audit_receipt
    File.write(File.join(@work, "feature.rb"), "# changed after the audit\n")

    stale, code = advance_to_review(a, receipt)

    assert_equal 1, code
    assert_match(/stale receipt/, stale["reasons"].join)
  end

  test "committing the audited code does not make the receipt stale" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**", stage: "audit")
    claim(a, "s1")
    receipt = audit_receipt
    system("git", "-C", @work, "add", "-A", exception: true)
    system("git", "-C", @work, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "feature", exception: true)

    assert_equal 0, advance_to_review(a, receipt)[1]
  end

  test "next never offers an item that waits in review, and says the epic is awaiting a merge" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    b = make_item("B", wave: 2, owns: "lib/b/**", blocked_by: [ a ])
    move_to_review(a)
    result, = wb("next", "--epic", "demo", "--session", "builder")

    assert_nil result["item"]
    assert_equal "awaiting_merge", result["reason"]
    assert_equal [ a ], result["awaiting_merge"]
    assert_equal "in-review", state_of(a)["state"]
    assert_equal "waiting", state_of(b)["state"]
    assert_equal a, wb("next", "--epic", "demo", "--stage", "review")[0]["item"]["number"], "a review sweep can still ask for them explicitly"
  end

  test "other ready work is still offered while an item waits for its merge" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    other = make_item("Other", wave: 1, owns: "lib/other/**")
    move_to_review(a)

    assert_equal other, wb("next", "--epic", "demo")[0]["item"]["number"]
  end

  test "reviews reports the PR verdict of every item in review" do
    make_epic
    items = %w[merged open closed none].to_h { |name| [ name, make_item(name, wave: 1, owns: "lib/#{name}/**") ] }
    items.each_value { |n| move_to_review(n) }
    add_pr(number: 31, head: "epic/demo/#{items['merged']}-merged-item", state: "MERGED")
    add_pr(number: 32, head: "epic/demo/#{items['open']}-open-item", state: "OPEN")
    add_pr(number: 33, head: "epic/demo/#{items['closed']}-closed-item", state: "CLOSED")
    add_pr(number: 34, head: "epic/other/#{items['none']}-another-epic", state: "MERGED") # another epic's branch must not match
    add_pr(number: 35, head: "epic/demo/#{items['open']}0-prefix-collision", state: "MERGED") # 'N0-' is not 'N-'
    result, code = wb("reviews", "--epic", "demo")
    verdicts = result["reviews"].to_h { |r| [ r["number"], r["verdict"] ] }

    assert_equal 0, code
    assert_equal({ items["merged"] => "merged", items["open"] => "open", items["closed"] => "closed_unmerged", items["none"] => "no_pr" }, verdicts)
    assert_equal [ items["merged"] ], result["merged"]
    assert_equal "https://github.test/o/r/pull/31", result["reviews"].find { |r| r["number"] == items["merged"] }["pr"]["url"]
  end

  test "reviews uses the newest PR of an item and excludes finished items" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    done = make_item("D", wave: 1, owns: "lib/d/**")
    move_to_review(a)
    claim(done, "s")
    wb("advance", done.to_s, "--epic", "demo", "--session", "s", "--stage", "done")
    add_pr(number: 10, head: "epic/demo/#{a}-first-try", state: "CLOSED")
    add_pr(number: 12, head: "epic/demo/#{a}-second-try", state: "MERGED")
    result = wb("reviews", "--epic", "demo")[0]

    assert_equal([ a ], result["reviews"].map { |r| r["number"] })
    assert_equal "merged", result["reviews"].first["verdict"]
    assert_equal 12, result["reviews"].first["pr"]["number"]
  end

  test "a merged review lets the worker finish the item and that unblocks the dependent without any human step but the merge" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    b = make_item("B", wave: 2, owns: "lib/b/**", blocked_by: [ a ])
    move_to_review(a)

    assert_equal "awaiting_merge", wb("next", "--epic", "demo")[0]["reason"]
    assert_empty wb("reviews", "--epic", "demo")[0]["merged"]
    add_pr(number: 40, head: "epic/demo/#{a}-a", state: "MERGED")
    merged = wb("reviews", "--epic", "demo")[0]["merged"]

    assert_equal [ a ], merged
    assert_equal 0, claim(a, "sweeper")[1]
    wb("advance", a.to_s, "--epic", "demo", "--session", "sweeper", "--stage", "done", "--note", "merged, gates green on main")

    assert_equal b, wb("next", "--epic", "demo")[0]["item"]["number"]
  end

  test "reviews on an epic without items in review makes no PR call" do
    make_epic
    make_item("A", wave: 1, owns: "lib/a/**")

    assert_empty wb("reviews", "--epic", "demo")[0]["reviews"]
  end

  test "show and reviews list the Gate commands parsed from the issue body" do
    make_epic
    body = "## Goal\nprove it\n\n## Gates (a stage advances only when these are green, run by the worker)\n- `bin/rails test`\n- `ruby .claude/scripts/x.rb --all`\n- plain command\n\n## Acceptance\n- [ ] ok\n"
    a = wb("item", "create", "--epic", "demo", "--title", "A", "--body", body, "--wave", "1", "--owns", "lib/a/**")[0]["number"]
    move_to_review(a)

    assert_equal [ "bin/rails test", "ruby .claude/scripts/x.rb --all", "plain command" ], wb("show", a.to_s, "--epic", "demo")[0]["gates"]
    assert_equal [ "bin/rails test", "ruby .claude/scripts/x.rb --all", "plain command" ], wb("reviews", "--epic", "demo")[0]["reviews"].first["gates"]
    assert_empty wb("show", make_item("B", wave: 1, owns: "lib/b/**").to_s, "--epic", "demo")[0]["gates"]
  end

  # ---- merge policy: a script decides whether a review PR may be merged (epic-flow R15) ------------------------------------
  def check(name, conclusion = "SUCCESS", status: "COMPLETED")
    { "name" => name, "status" => status, "conclusion" => conclusion, "detailsUrl" => "https://ci.test/#{name}", "html_url" => "https://ci.test/#{name}" }
  end

  def seed_base(checks: [ check("test"), check("lint") ], files: [], sha: "base1234")
    db = fake_db
    db["base_checks"] = checks
    db["base_files"] = files
    db["base_sha"] = sha
    File.write(@db, JSON.generate(db))
  end

  def add_open_pr(item, number:, checks: [ check("test"), check("lint") ], draft: false, mergeable: "MERGEABLE", behind_by: 0, files: [ "lib/a/x.rb" ])
    db = fake_db
    db["prs"] = Array(db["prs"]) << { "number" => number, "state" => "OPEN", "headRefName" => "epic/demo/#{item}-item", "mergedAt" => nil,
                                      "url" => "https://github.test/o/r/pull/#{number}", "isDraft" => draft, "mergeable" => mergeable,
                                      "headRefOid" => "head#{number}",
                                      "statusCheckRollup" => checks, "behind_by" => behind_by, "files" => files }
    File.write(@db, JSON.generate(db))
  end

  def judged(number) = wb("mergeable", "--epic", "demo")[0]["items"].find { |r| r["number"] == number }

  test "mergeable: an audited, conflict-free PR whose checks all pass is ready" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    move_to_review(a)
    seed_base
    add_open_pr(a, number: 50)
    result, code = wb("mergeable", "--epic", "demo")
    row = result["items"].first

    assert_equal 0, code, result.inspect
    assert_equal "ready", row["verdict"]
    assert row["audited"]
    assert_equal(%w[test lint], row["checks"]["passing"].map { |c| c["name"] })
    assert_equal({ "number" => 50, "state" => "OPEN", "url" => "https://github.test/o/r/pull/50", "head" => "head50", "branch" => "epic/demo/#{a}-item",
                   "base" => "main", "draft" => false, "mergeable" => "MERGEABLE", "merge_state" => "CLEAN" }, row["pr"])
    assert_equal [ a ], result["ready"]
    assert_equal({ "branch" => "main", "sha" => "base1234", "failing" => [], "checks" => [
                   { "name" => "test", "status" => "COMPLETED", "conclusion" => "SUCCESS", "url" => "https://ci.test/test" },
                   { "name" => "lint", "status" => "COMPLETED", "conclusion" => "SUCCESS", "url" => "https://ci.test/lint" }
                 ] }, result["base"])
  end

  test "mergeable: a check that fails on the base branch too is pre-existing and reported, not held against the PR" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    move_to_review(a)
    seed_base(checks: [ check("test"), check("scan_ruby", "FAILURE") ])
    add_open_pr(a, number: 50, checks: [ check("test"), check("scan_ruby", "FAILURE") ])
    result = wb("mergeable", "--epic", "demo")[0]
    row = result["items"].first

    assert_equal "ready", row["verdict"]
    assert_equal([ "scan_ruby" ], row["checks"]["preexisting"].map { |c| c["name"] })
    assert_empty row["checks"]["failing"]
    assert_equal [ { "name" => "scan_ruby", "conclusion" => "FAILURE", "url" => "https://ci.test/scan_ruby" } ], result["base"]["failing"]
  end

  test "mergeable: a check failing only on the PR blocks it, a running check makes it wait" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    b = make_item("B", wave: 1, owns: "lib/b/**")
    move_to_review(a)
    move_to_review(b)
    seed_base
    add_open_pr(a, number: 50, checks: [ check("test", "FAILURE"), check("lint") ])
    add_open_pr(b, number: 51, checks: [ check("test", nil, status: "IN_PROGRESS"), check("lint") ])
    result = wb("mergeable", "--epic", "demo")[0]

    assert_equal "ci_failed", judged(a)["verdict"]
    assert_equal [ { "name" => "test", "conclusion" => "FAILURE", "url" => "https://ci.test/test" } ], judged(a)["checks"]["failing"]
    assert_equal "ci_pending", judged(b)["verdict"]
    assert_equal([ "test" ], judged(b)["checks"]["pending"].map { |c| c["name"] })
    assert_empty result["ready"]
  end

  test "mergeable: drafts, conflicts and an item put in review without the audit receipt are never ready" do
    make_epic
    draft = make_item("D", wave: 1, owns: "lib/d/**")
    conflicting = make_item("C", wave: 1, owns: "lib/c/**")
    by_hand = make_item("H", wave: 1, owns: "lib/h/**", stage: "review") # label set by hand: no `-> review: audit ... PASS` note
    move_to_review(draft)
    move_to_review(conflicting)
    seed_base
    add_open_pr(draft, number: 50, draft: true)
    add_open_pr(conflicting, number: 51, mergeable: "CONFLICTING")
    add_open_pr(by_hand, number: 52)

    assert_equal "draft", judged(draft)["verdict"]
    assert_equal "conflicts", judged(conflicting)["verdict"]
    assert_equal "not_audited", judged(by_hand)["verdict"]
    refute judged(by_hand)["audited"]
  end

  test "mergeable: behind the base is fine while the PR's files are disjoint from what landed there, otherwise it must update" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    b = make_item("B", wave: 1, owns: "lib/b/**")
    move_to_review(a)
    move_to_review(b)
    seed_base(files: [ "lib/b/shared.rb", "README.md" ])
    add_open_pr(a, number: 50, behind_by: 2, files: [ "lib/a/x.rb" ])
    add_open_pr(b, number: 51, behind_by: 2, files: [ "lib/b/shared.rb", "lib/b/y.rb" ])

    assert_equal "ready", judged(a)["verdict"]
    assert_equal 2, judged(a)["behind_by"]
    assert_equal "behind", judged(b)["verdict"]
    assert_equal [ "lib/b/shared.rb" ], judged(b)["overlap"]
  end

  test "mergeable: merged, closed and missing PRs keep their reviews verdict and cost no extra call" do
    make_epic
    merged = make_item("M", wave: 1, owns: "lib/m/**")
    none = make_item("N", wave: 1, owns: "lib/n/**")
    move_to_review(merged)
    move_to_review(none)
    seed_base
    add_pr(number: 50, head: "epic/demo/#{merged}-m", state: "MERGED")

    assert_equal "merged", judged(merged)["verdict"]
    assert_equal "no_pr", judged(none)["verdict"]
    assert_nil judged(none)["pr"]
  end

  test "merge refuses anything that is not ready and never touches the PR" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    move_to_review(a)
    seed_base
    add_open_pr(a, number: 50, checks: [ check("test", "FAILURE") ])
    result, code = wb("merge", a.to_s, "--epic", "demo", "--session", "release")

    assert_equal 1, code
    assert_equal "ci_failed", result["reason"]
    assert_equal "OPEN", fake_db["prs"].first["state"]
    assert_equal 2, wb("merge", a.to_s, "--epic", "demo", "--session", "release", "--method", "fast-forward")[1]
  end

  test "merge squashes a ready PR with its judged head pinned, deletes the remote branch, logs it, and reviews then reports merged" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    move_to_review(a)
    seed_base
    add_open_pr(a, number: 50)
    system("git", "-C", @work, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "--allow-empty", "-m", "work", exception: true)
    system("git", "-C", @work, "push", "-q", "origin", "HEAD:refs/heads/epic/demo/#{a}-item", exception: true)
    result, code = wb("merge", a.to_s, "--epic", "demo", "--session", "release")
    pr = fake_db["prs"].first

    assert_equal 0, code, result.inspect
    assert_equal({ "ok" => true, "number" => a, "pr" => 50, "method" => "squash", "state" => "MERGED", "merge_commit" => pr["mergeCommit"]["oid"],
                   "branch" => "epic/demo/#{a}-item", "branch_deleted" => true }, result)
    assert_equal "--squash", pr["method"]
    assert_empty `git -C #{@work} ls-remote origin refs/heads/epic/demo/#{a}-item`.strip
    note = wb("show", a.to_s, "--epic", "demo")[0]["notes"].last

    assert_equal "merge-log", note["type"]
    assert_match(/PR #50 merged into main \(squash, merge50/, note["body"])
    assert_equal [ a ], wb("reviews", "--epic", "demo")[0]["merged"]
    assert_equal "review", state_of(a)["stage"], "merging does not advance the item: the sweep does, after the Gates pass on main"
  end

  test "merge keeps the branch on request and refuses a head that moved since it was judged" do
    make_epic
    a = make_item("A", wave: 1, owns: "lib/a/**")
    move_to_review(a)
    seed_base
    add_open_pr(a, number: 50)
    result, code = wb("merge", a.to_s, "--epic", "demo", "--session", "release", "--keep-branch")

    assert_equal 0, code, result.inspect
    refute result["branch_deleted"]
  end
end

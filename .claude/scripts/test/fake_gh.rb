#!/usr/bin/env ruby
# frozen_string_literal: true

# Minimal stand-in for the `gh` CLI, backed by a JSON file (WORK_FAKE_DB), used to test .claude/scripts/epic/work_board.rb
# without touching GitHub. Output shapes follow `gh` 2.87: issue number/title/state (OPEN|CLOSED)/labels [{name}]/body/
# createdAt/comments [{body, createdAt, author{login}}]. The file is locked, so concurrent processes can race safely.
#
# Used two ways: in-process (FakeGh.call(argv), fast, most tests) or as an executable (WORK_GH="ruby fake_gh.rb", the real
# subprocess path, used by the concurrency test).
# Supported: issue create|list|view|edit (labels and body)|comment|close|reopen, label create, pr list|view|merge, and the two `api` reads the merge
# policy needs (compare, check-runs on the base branch). Pull requests and base-branch facts are seeded by tests in db["prs"],
# db["base_checks"], db["base_files"] and db["base_sha"].

require "json"
require "time"

class FakeGh
  class Error < StandardError; end

  def self.call(argv) = new(ENV.fetch("WORK_FAKE_DB")).call(argv)

  def initialize(path)
    @path = path
  end

  def call(argv)
    group, verb, *args = argv
    return api(verb) if group == "api"

    case [ group, verb ]
    when %w[issue create] then create(args)
    when %w[issue list] then list(args)
    when %w[pr list] then pr_list(args)
    when %w[pr view] then JSON.generate(pr_defaults(find_pr(args.first)))
    when %w[pr merge] then pr_merge(args)
    when %w[issue view] then JSON.generate(view(find(args.first)))
    when %w[issue edit] then edit(args)
    when %w[issue comment] then comment(args)
    when %w[issue close], %w[issue reopen] then mutate(args.first) { |i| i["state"] = verb == "close" ? "CLOSED" : "OPEN" }
    when %w[label create] then locked { |db| db["labels"] |= [ args.first ] } && ""
    else raise Error, "fake gh: unsupported #{argv.first(2).join(' ')}"
    end
  end

  private

  def locked
    File.open("#{@path}.lock", File::CREAT | File::RDWR) do |lock|
      lock.flock(File::LOCK_EX)
      db = File.exist?(@path) ? JSON.parse(File.read(@path)) : { "issues" => [], "labels" => [], "next" => 1 }
      result = yield db
      File.write(@path, JSON.generate(db))
      result
    end
  end

  def flag(args, name) = (i = args.index(name)) ? args[i + 1] : nil
  def flag_values(args, name) = args.each_index.flat_map { |i| args[i] == name ? args[i + 1].to_s.split(",") : [] }
  def body_of(args) = flag(args, "--body-file") ? File.read(flag(args, "--body-file")) : flag(args, "--body").to_s
  def view(issue) = issue.slice("number", "title", "state", "labels", "body", "createdAt", "comments")

  def find(number)
    locked { |db| db["issues"].find { |i| i["number"] == number.to_i } } || raise(Error, "issue #{number} not found")
  end

  def mutate(number)
    locked do |db|
      issue = db["issues"].find { |i| i["number"] == number.to_i } or raise Error, "issue #{number} not found"
      yield issue
    end
    ""
  end

  # Real gh rejects labels that do not exist in the repository (create, add and remove alike).
  def require_labels!(db, names)
    missing = names - db["labels"]
    raise Error, "'#{missing.first}' not found" if missing.any?
  end

  def create(args)
    body = body_of(args)
    number = locked do |db|
      require_labels!(db, flag_values(args, "--label"))
      n = db["next"]
      db["next"] += 1
      db["issues"] << { "number" => n, "title" => flag(args, "--title"), "state" => "OPEN", "body" => body,
                        "labels" => flag_values(args, "--label").map { |l| { "name" => l } }, "createdAt" => Time.now.utc.iso8601, "comments" => [] }
      n
    end
    "https://github.test/owner/repo/issues/#{number}"
  end

  def list(args)
    wanted = flag_values(args, "--label")
    state = flag(args, "--state") || "open"
    rows = locked { |db| db["issues"].dup }
    rows = rows.select { |i| (wanted - i["labels"].map { |l| l["name"] }).empty? }
    rows = rows.select { |i| state == "all" || i["state"].downcase == state }
    JSON.generate(rows.map { |i| view(i) })
  end

  # Pull requests are seeded by tests in db["prs"] (number, state OPEN|CLOSED|MERGED, headRefName, mergedAt, url).
  def pr_list(args)
    state = (flag(args, "--state") || "open").downcase
    rows = locked { |db| Array(db["prs"]).dup }
    rows = rows.select { |pr| state == "all" || pr["state"].downcase == state }
    JSON.generate(rows)
  end

  def find_pr(number)
    locked { |db| Array(db["prs"]).find { |pr| pr["number"] == number.to_i } } || raise(Error, "no pull requests found for #{number}")
  end

  # Fields `gh pr view --json` returns that tests may leave out.
  def pr_defaults(pr)
    { "isDraft" => false, "mergeable" => "MERGEABLE", "mergeStateStatus" => "CLEAN", "headRefOid" => "head#{pr['number']}",
      "baseRefName" => "main", "statusCheckRollup" => [], "mergeCommit" => nil }.merge(pr)
  end

  # Real gh refuses --match-head-commit when the head moved, and merging a PR that is not open.
  def pr_merge(args)
    locked do |db|
      pr = Array(db["prs"]).find { |p| p["number"] == args.first.to_i } or raise Error, "no pull requests found for #{args.first}"
      raise Error, "pull request ##{pr['number']} is not open" unless pr["state"] == "OPEN"
      expected = flag(args, "--match-head-commit")
      raise Error, "head commit #{pr_defaults(pr)['headRefOid']} does not match #{expected}" if expected && expected != pr_defaults(pr)["headRefOid"]

      pr["state"] = "MERGED"
      pr["mergedAt"] = Time.now.utc.iso8601
      pr["mergeCommit"] = { "oid" => "merge#{pr['number']}#{'0' * 30}" }
      pr["method"] = args.find { |a| %w[--squash --merge --rebase].include?(a) }
    end
    ""
  end

  # repos/{owner}/{repo}/compare/BASE...HEAD and repos/{owner}/{repo}/commits/BASE/check-runs, the two reads work_board.rb makes.
  def api(path)
    db = locked { |d| d }
    base = ENV.fetch("WORK_BASE", "main")
    case path
    when %r{/commits/#{Regexp.escape(base)}/check-runs}
      JSON.generate({ "check_runs" => Array(db["base_checks"]).map { |c| { "head_sha" => db["base_sha"] || "base0000" }.merge(c) } })
    when %r{/compare/#{Regexp.escape(base)}\.\.\.(\S+)\z}
      pr = Array(db["prs"]).find { |p| pr_defaults(p)["headRefOid"] == Regexp.last_match(1) } or raise Error, "HTTP 404: No commit found for SHA: #{Regexp.last_match(1)}"
      JSON.generate({ "behind_by" => pr["behind_by"].to_i, "ahead_by" => 1, "base_commit" => { "sha" => db["base_sha"] || "base0000" },
                      "merge_base_commit" => { "sha" => "mergebase" }, "files" => Array(pr["files"]).map { |f| { "filename" => f } } })
    when %r{/compare/\S+\.\.\.#{Regexp.escape(base)}\z}
      JSON.generate({ "files" => Array(db["base_files"]).map { |f| { "filename" => f } } })
    else raise Error, "fake gh: unsupported api #{path}"
    end
  end

  def edit(args)
    locked { |db| require_labels!(db, flag_values(args, "--add-label") + flag_values(args, "--remove-label")) }
    body = flag(args, "--body-file") || flag(args, "--body") ? body_of(args) : nil
    mutate(args.first) do |i|
      names = i["labels"].map { |l| l["name"] }
      names |= flag_values(args, "--add-label")
      names -= flag_values(args, "--remove-label")
      i["labels"] = names.map { |n| { "name" => n } }
      i["body"] = body unless body.nil?
    end
  end

  def comment(args)
    body = body_of(args)
    mutate(args.first) { |i| i["comments"] << { "body" => body, "createdAt" => Time.now.utc.iso8601, "author" => { "login" => "fake" } } }
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    out = FakeGh.call(ARGV)
    puts out unless out.empty?
  rescue FakeGh::Error => e
    warn e.message
    exit 1
  end
end

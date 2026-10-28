#!/usr/bin/env ruby
# frozen_string_literal: true

# Coordination board for multi-session epics. GitHub issues + labels are the source of truth for scope and stage;
# an atomic git ref (refs/claims/<epic>/<issue>) is the lock that says which session is working an item.
# Agents never call `gh` or craft GraphQL themselves: they call this script.
#
#   work_board.rb session                                  # stable id of this checkout's session (tmp/epic/session)
#   work_board.rb epic create --slug S --title T --body-file F
#   work_board.rb epic done --epic S --session ID [--note TXT]   # close the epic: refuses while an item is not done; posts an announce note, closes the root
#   work_board.rb item create --epic S --title T --body-file F --wave N --owns a,b [--blocked-by 1,2] [--stage plan] [--priority N]
#   work_board.rb plan-check --file plan.json              # lint a plan BEFORE creating anything (same rules as validate + contract fields)
#   work_board.rb plan-apply --file plan.json              # create the epic root + all items in dependency order (refuses an existing epic)
#   work_board.rb item amend N --epic S --session ID [--owns GLOBS] [--add-owns GLOBS] [--blocked-by N,M] [--add-blocked-by N,M] --reason TXT
#       rewrites the work-item meta and the Owns / Blocked by sections of an item, posts an announce note on the epic root (reason, before, after); refuses
#       a done item, an item held by another session and a result that adds an overlap or a cycle (plan lint).
#   work_board.rb validate --epic S                        # plan lint on created issues: deps exist, no cycles, owns present and non-overlapping
#   work_board.rb show N --epic S                          # one item: stage, meta, body, notes (what a worker reads before starting)
#   work_board.rb status --epic S
#   work_board.rb next --epic S [--session ID] [--stage a,b]   # best claimable item, or why none
#   work_board.rb reviews --epic S [--item N]               # items in stage review with their PR verdict: merged | open | closed_unmerged | no_pr
#   work_board.rb mergeable --epic S [--item N]             # reviews + the merge policy on every open PR (CI vs main, audit receipt, conflicts,
#                                                           # files behind main); verdict ready | ci_pending | ci_failed | behind | conflicts | draft |
#                                                           # not_audited | unknown_mergeability. Also reports the checks failing on main itself.
#   work_board.rb merge N --epic S --session ID [--method squash|merge|rebase] [--keep-branch]
#       merges the item's PR only when `mergeable` says ready (head pinned with --match-head-commit), deletes the remote branch, logs a note.
#       The only merge door; /work never calls it, /work-merge (run by a human) does (epic-flow R13).
#   work_board.rb claim N --epic S --session ID [--lease 45]   # atomic; exit 1 when someone else holds it
#   work_board.rb heartbeat N --epic S --session ID [--lease 45]
#   work_board.rb release N --epic S --session ID [--force]   # --force: a human frees an abandoned claim of any session
#   work_board.rb advance N --epic S --session ID --stage X [--keep] [--note TXT] [--audit-receipt FILE]
#       --stage review needs --audit-receipt: the scorecard.json /audit-feature wrote (audit_receipt.rb), every score >= 8, verdict PASS,
#       no mandatory finding open and the receipt's tree equal to the code in the current directory (run it inside the item worktree).
#   work_board.rb block N --epic S --session ID --reason TXT
#   work_board.rb unblock N --epic S
#   work_board.rb comment N --epic S --session ID --type shared|lesson|handoff|blocker|announce (--body TXT | --body-file F)
#   work_board.rb digest --epic S [--item N] [--format json|md]
#   work_board.rb reap --epic S                            # free claims whose lease expired
#
# Env: WORK_GH (default `gh`), WORK_REMOTE (default `origin`), WORK_BASE (default `main`), WORK_NOW (ISO time, tests),
# WORK_SESSION (else CLAUDE_CODE_SESSION_ID, else tmp/epic/session).
# `next` never offers items in stage `review` unless --stage includes it: a review item waits for a human merge; `reviews` tells which
# of them were merged, so a worker can verify the gates on main and advance them to done (which unblocks their dependents).
# Output is always one JSON object on stdout (digest --format md prints markdown). Exit 0 ok, 1 negative answer
# (claim lost, validation findings), 2 error.

require "json"
require "optparse"
require "open3"
require "shellwords"
require "securerandom"
require "socket"
require "tempfile"
require_relative "../audit_receipt"
require "time"
require "fileutils"

module WorkBoard
  class Failure < StandardError; end

  STAGES = %w[plan test-plan build gates audit fix review done].freeze
  AUDIT_MIN = 8 # every scorecard dimension (epic-flow R10)
  MERGE_METHODS = %w[squash merge rebase].freeze
  NOTE_TYPES = %w[shared lesson handoff blocker announce].freeze
  BLOCKING_LABELS = %w[blocked needs-human].freeze
  CLAIM_NS = "refs/claims"
  LOCAL_NS = "refs/claims-remote"
  DEFAULT_LEASE_MIN = 45
  META = /<!--\s*work-item\s*(\{.*?\})\s*-->/m
  NOTE = /<!--\s*work-note\s*(\{.*?\})\s*-->/m
  EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d6a5c65b3dd3d"

  def self.now = ENV["WORK_NOW"] ? Time.parse(ENV["WORK_NOW"]).utc : Time.now.utc
  def self.base = ENV.fetch("WORK_BASE", "main")

  # ---- process helpers ----------------------------------------------------------------------------------------
  module Shell
    def run(argv, stdin: nil, env: {})
      out, err, status = Open3.capture3(env, *argv, stdin_data: stdin.to_s)
      [ out, err, status ]
    end

    def gh(*args)
      out, err, status = run(Shellwords.split(ENV.fetch("WORK_GH", "gh")) + args)
      raise Failure, "gh #{args.first(3).join(' ')} failed: #{err.strip}" unless status.success?

      out
    end

    def gh_json(*args) = JSON.parse(gh(*args))

    def git(*args, ok: false)
      env = { "GIT_AUTHOR_NAME" => "work-board", "GIT_AUTHOR_EMAIL" => "work-board@localhost",
              "GIT_COMMITTER_NAME" => "work-board", "GIT_COMMITTER_EMAIL" => "work-board@localhost" }
      out, err, status = run([ "git", *args ], env: env)
      return [ status.success?, out, err ] if ok
      raise Failure, "git #{args.first(2).join(' ')} failed: #{err.strip}" unless status.success?

      out
    end
  end

  # ---- issue model --------------------------------------------------------------------------------------------
  class Item
    attr_reader :number, :title, :labels, :meta, :body

    def initialize(raw)
      @number = raw.fetch("number")
      @title = raw["title"].to_s
      @closed = raw["state"].to_s.upcase == "CLOSED"
      @labels = Array(raw["labels"]).map { |l| l.is_a?(Hash) ? l["name"] : l.to_s }
      @body = raw["body"].to_s
      @meta = (m = @body[META, 1]) ? JSON.parse(m) : {}
    end

    # The Gate commands of the issue body (`## Gates` section, one `- \`cmd\`` per line): what the merge sweep runs on main.
    def gates
      section = @body.split(/^##\s+/).find { |s| s.start_with?("Gates") }
      return [] unless section

      section.lines.drop(1).filter_map { |l| l[/\A-\s+`([^`]+)`/, 1] || l[/\A-\s+(\S.*)/, 1]&.strip }
    end

    def root? = labels.include?("epic-root")
    def closed? = @closed
    def stage = labels.find { |l| l.start_with?("stage:") }&.delete_prefix("stage:") || "plan"
    def done? = closed? || stage == "done"
    def blocked? = (labels & BLOCKING_LABELS).any?
    def wave = meta.fetch("wave", 0).to_i
    def priority = meta.fetch("priority", 0).to_i
    def owns = Array(meta["owns"])
    def blocked_by = Array(meta["blocked_by"]).map(&:to_i)

    # The body with the Owns and Blocked by sections and the meta block rewritten. A kept entry keeps its line (blockers carry a
    # trailing explanation), a new one gets a plain line. Raises (nothing is written) when a section or the meta block is missing, or
    # when a section holds a line that is not a bullet: the rewrite would drop text a person wrote.
    def with_contract(owns:, blocked_by:)
      text = @body.dup
      rewrite = lambda do |title, entries, key, make|
        pattern = /^## #{title}[ \t]*\r?\n(.*?)(?=^## |^<!--|\z)/m
        raise Failure, "item ##{number} has no `## #{title}` section to amend" unless text.match?(pattern)

        old = text[pattern, 1].lines.map(&:chomp).reject { |line| line.strip.empty? || line.strip == "- nothing" }
        stray = old.reject { |line| line.start_with?("- ") && key.call(line) }
        raise Failure, "item ##{number}: `## #{title}` holds a line the rewrite would drop (#{stray.first.strip.inspect}), amend it by hand" if stray.any?

        multi = old.find { |line| line.scan(/`[^`]+`/).size > 1 } if title == "Owns"
        raise Failure, "item ##{number}: `## Owns` has a bullet with several globs (#{multi.strip.inspect}), amend it by hand" if multi

        lines = entries.map { |entry| old.find { |line| key.call(line) == entry.to_s } || make.call(entry) }
        text.sub!(pattern) { "## #{title}\n#{lines.empty? ? '- nothing' : lines.join("\n")}\n\n" }
      end
      rewrite.call("Owns", owns, ->(line) { line[/\A-\s+`([^`]+)`/, 1] }, ->(glob) { "- `#{glob}`" })
      rewrite.call("Blocked by", blocked_by, ->(line) { line[/\A-\s+#(\d+)\b/, 1] }, ->(blocker) { "- ##{blocker}" })
      raise Failure, "item ##{number} has no work-item meta block" unless text.match?(META)

      amended = meta.merge("owns" => owns, "blocked_by" => blocked_by)
      text = text.sub(META) { "<!-- work-item #{JSON.generate(amended)} -->" }
      @body.include?("\r\n") ? text.gsub(/\r?\n/, "\r\n") : text # a body edited on GitHub's web UI keeps its line endings
    end

    def summary
      { number: number, title: title, stage: stage, wave: wave, owns: owns, blocked_by: blocked_by, labels: labels }
    end
  end

  # Whether the PR of an item in review may be merged. A pure judgement on facts the Board fetched, so a script and not the
  # agent's reading of a checks page decides (epic-flow R15). A check that fails on the PR AND on the base branch is
  # pre-existing: it is reported, not held against the PR; the merge sweep re-runs the item's Gates on main anyway (R14).
  module MergePolicy
    FAILED = %w[FAILURE TIMED_OUT CANCELLED ACTION_REQUIRED STARTUP_FAILURE ERROR].freeze
    PENDING = %w[PENDING EXPECTED QUEUED IN_PROGRESS WAITING REQUESTED].freeze

    # pr: `gh pr view` JSON; base_checks: check runs on the base branch head; pr_files / base_files: paths changed by the PR /
    # on the base since the merge base (only when behind_by > 0).
    def self.judge(pr:, audited:, base_checks:, behind_by:, pr_files:, base_files:)
      checks = classify(pr["statusCheckRollup"], base_checks)
      overlap = behind_by.positive? ? (pr_files & base_files) : []
      verdict = if pr["isDraft"] then "draft"
      elsif !audited then "not_audited"
      elsif pr["mergeable"] == "CONFLICTING" then "conflicts"
      elsif pr["mergeable"] != "MERGEABLE" then "unknown_mergeability"
      elsif checks[:pending].any? then "ci_pending"
      elsif checks[:failing].any? then "ci_failed"
      elsif overlap.any? then "behind"
      else "ready"
      end
      { verdict: verdict, checks: checks, behind_by: behind_by, overlap: overlap }
    end

    # `statusCheckRollup` mixes CheckRun (status/conclusion/name/detailsUrl) and StatusContext (state/context/targetUrl) shapes.
    def self.classify(rollup, base_checks)
      base = Array(base_checks).to_h { |c| [ c["name"], c["conclusion"].to_s.upcase ] }
      result = { passing: [], failing: [], preexisting: [], pending: [] }
      Array(rollup).each do |c|
        name = c["name"] || c["context"]
        status = (c["status"] || "COMPLETED").to_s.upcase
        conclusion = (c["conclusion"] || c["state"]).to_s.upcase
        entry = { name: name, conclusion: conclusion, url: c["detailsUrl"] || c["targetUrl"] }
        if status != "COMPLETED" || PENDING.include?(conclusion) then result[:pending] << entry
        elsif FAILED.include?(conclusion) then (FAILED.include?(base[name]) ? result[:preexisting] : result[:failing]) << entry
        else result[:passing] << entry
        end
      end
      result
    end

    def self.failing(base_checks)
      Array(base_checks).select { |c| FAILED.include?(c["conclusion"].to_s.upcase) }
                        .map { |c| { name: c["name"], conclusion: c["conclusion"].to_s.upcase, url: c["html_url"] || c["detailsUrl"] } }
    end
  end

  # Two ownership globs conflict when one's literal prefix contains the other's.
  def self.owns_overlap?(a, b)
    a.product(b).any? do |x, y|
      px = x.split(/[*?\[{]/, 2).first.to_s
      py = y.split(/[*?\[{]/, 2).first.to_s
      px.start_with?(py) || py.start_with?(px)
    end
  end

  # Plan rules shared by `plan-check` (keys, before creation) and `validate` (issue numbers, after creation).
  module Plan
    REQUIRED_FIELDS = %w[key title wave owns goal gates acceptance].freeze

    def self.ancestors(deps, start)
      seen = []
      stack = deps.fetch(start, []).dup
      until stack.empty?
        n = stack.pop
        next if seen.include?(n)

        seen << n
        stack.concat(deps.fetch(n, []))
      end
      seen
    end

    # nodes: [{ id:, wave:, owns: [], blocked_by: [], stage: }]
    def self.check(nodes)
      findings = []
      add = ->(code, id, detail) { findings << { code: code, item: id, detail: detail } }
      ids = nodes.map { |n| n[:id] }
      ids.tally.select { |_, c| c > 1 }.each_key { |id| add.call("DUPLICATE_ID", id, "used more than once") }
      by_id = nodes.to_h { |n| [ n[:id], n ] }
      nodes.each do |n|
        add.call("OWNS_MISSING", n[:id], "no owns globs") if n[:owns].empty?
        add.call("STAGE_INVALID", n[:id], n[:stage].to_s) unless STAGES.include?(n[:stage])
        n[:blocked_by].each do |d|
          dep = by_id[d]
          add.call("BLOCKER_MISSING", n[:id], "#{d} is not an item of this epic") unless dep
          add.call("WAVE_ORDER", n[:id], "wave #{n[:wave]} but blocked by #{d} in wave #{dep[:wave]}") if dep && dep[:wave] >= n[:wave]
        end
      end
      deps = nodes.to_h { |n| [ n[:id], n[:blocked_by] ] }
      nodes.each { |n| add.call("CYCLE", n[:id], "depends on itself") if ancestors(deps, n[:id]).include?(n[:id]) }
      nodes.combination(2).each do |a, c|
        related = ancestors(deps, a[:id]).include?(c[:id]) || ancestors(deps, c[:id]).include?(a[:id])
        next if related || !WorkBoard.owns_overlap?(a[:owns], c[:owns])

        add.call("OWNS_OVERLAP", a[:id], "#{a[:id]} and #{c[:id]} can run in parallel but own overlapping files (#{a[:owns].join(',')} / #{c[:owns].join(',')})")
      end
      findings
    end

    # Contract fields every planned item must carry: what to do, what judges it, when it is done.
    def self.check_plan_file(plan)
      findings = []
      add = ->(code, id, detail) { findings << { code: code, item: id, detail: detail } }
      add.call("PLAN_SHAPE", nil, "epic.slug and epic.title are required") unless plan.dig("epic", "slug").to_s.match?(/\A[a-z0-9][a-z0-9-]*\z/) && plan.dig("epic", "title").to_s != ""
      items = Array(plan["items"])
      add.call("PLAN_SHAPE", nil, "items must be a non-empty array") if items.empty?
      items.each do |i|
        REQUIRED_FIELDS.each do |f|
          v = i[f]
          add.call("FIELD_MISSING", i["key"], f) if v.nil? || (v.respond_to?(:empty?) && v.empty?)
        end
        add.call("GATES_NOT_COMMANDS", i["key"], "gates must be shell commands in a list") unless Array(i["gates"]).all? { |g| g.is_a?(String) && !g.strip.empty? }
      end
      nodes = items.map { |i| { id: i["key"], wave: i["wave"].to_i, owns: Array(i["owns"]), blocked_by: Array(i["blocked_by"]), stage: i["stage"] || "plan" } }
      findings + check(nodes)
    end

    # The board's contract appended to an issue that `item adopt` takes into an epic: the original report stays above it.
    def self.adopted_section(meta, gates)
      deps = Array(meta[:blocked_by]).map { |n| "- ##{n}" }
      <<~MD
        ## Work item (adopted into epic `#{meta[:epic]}`)
        The text above is the original report. The sections below are the board's contract (epic-flow): a worker changes only
        the files in Owns, starts when every blocker is done and advances a stage only when the Gates are green.

        ## Owns
        #{Array(meta[:owns]).map { |o| "- `#{o}`" }.join("\n")}

        ## Blocked by
        #{deps.empty? ? '- nothing' : deps.join("\n")}

        ## Gates (a stage advances only when these are green, run by the worker)
        #{gates.map { |g| "- `#{g}`" }.join("\n")}

      MD
    end

    def self.body(item, numbers)
      deps = Array(item["blocked_by"]).map { |k| "- ##{numbers.fetch(k)} (#{k})" }
      <<~MD
        ## Goal
        #{item['goal']}

        ## Owns
        #{Array(item['owns']).map { |o| "- `#{o}`" }.join("\n")}

        ## Blocked by
        #{deps.empty? ? '- nothing' : deps.join("\n")}

        ## Gates (a stage advances only when these are green, run by the worker)
        #{Array(item['gates']).map { |g| "- `#{g}`" }.join("\n")}

        ## Acceptance
        #{Array(item['acceptance']).map { |a| "- [ ] #{a}" }.join("\n")}
        #{item['context'].to_s.empty? ? '' : "\n## Context\n#{item['context']}\n"}
      MD
    end
  end

  class Board
    include Shell

    def initialize(slug)
      @slug = slug
    end

    # -- reading ---------------------------------------------------------------------------------------------
    def all_issues
      @all_issues ||= gh_json("issue", "list", "--label", "epic:#{@slug}", "--state", "all", "--limit", "500",
                              "--json", "number,title,state,labels,body,createdAt").map { |r| Item.new(r) }
    end

    def root = all_issues.find(&:root?)
    def items = all_issues.reject(&:root?)
    def item(number) = items.find { |i| i.number == number } || raise(Failure, "issue ##{number} is not an item of epic #{@slug}")
    def done_numbers = items.select(&:done?).map(&:number)

    def comments(number)
      gh_json("issue", "view", number.to_s, "--json", "comments").fetch("comments").map do |c|
        note = c["body"].to_s[NOTE, 1]
        meta = note ? JSON.parse(note) : {}
        { number: number, type: meta["type"], session: meta["session"], stage: meta["stage"], at: meta["at"] || c["createdAt"],
          body: c["body"].to_s.sub(NOTE, "").strip, note: !note.nil? }
      end
    end

    # PRs of item branches `epic/<slug>/<number>-<title>`; the newest PR of an item wins.
    def pull_request_for(number, prs)
      prefix = "epic/#{@slug}/#{number}"
      prs.select { |pr| pr["headRefName"] == prefix || pr["headRefName"].to_s.start_with?("#{prefix}-") }.max_by { |pr| pr["number"] }
    end

    def pull_requests
      gh_json("pr", "list", "--state", "all", "--limit", "200", "--json", "number,state,headRefName,mergedAt,url")
    end

    # -- merge policy facts ------------------------------------------------------------------------------------
    def pull_request(number)
      gh_json("pr", "view", number.to_s, "--json", "number,url,state,isDraft,mergeable,mergeStateStatus,headRefOid,headRefName,baseRefName,statusCheckRollup,mergeCommit")
    end

    # GitHub's three-dot compare: files are the changes on `head` since the merge base; base_commit is the tip of `base`.
    def compare(base, head) = gh_json("api", "repos/{owner}/{repo}/compare/#{base}...#{head}")

    def base_check_runs
      gh_json("api", "repos/{owner}/{repo}/commits/#{WorkBoard.base}/check-runs?per_page=100").fetch("check_runs", [])
    end

    # `advance --stage review` only succeeds with a passing audit receipt and logs it; an item labelled review by hand has no such note.
    def audited?(number)
      comments(number).any? { |c| c[:note] && c[:type] == "stage-log" && c[:body].match?(/-> review: audit min=\d+ verdict=PASS/) }
    end

    def merge_pull_request(number, method:, head:)
      gh("pr", "merge", number.to_s, "--#{method}", "--match-head-commit", head)
    end

    def delete_remote_branch(name)
      ok, = git("push", "-q", WorkBoard.remote, "--delete", name, ok: true)
      ok
    end

    # -- claims (git refs) -----------------------------------------------------------------------------------
    def claims
      # A failed fetch must raise: swallowing it would read as "nobody holds anything".
      git("fetch", "-q", "--prune", WorkBoard.remote, "+#{CLAIM_NS}/#{@slug}/*:#{LOCAL_NS}/#{@slug}/*")
      out = git("for-each-ref", "--format=%(refname)%09%(objectname)%09%(contents:subject)", "#{LOCAL_NS}/#{@slug}")
      out.lines.to_h do |line|
        ref, sha, subject = line.chomp.split("\t", 3)
        data = JSON.parse(subject) rescue {}
        expires = Time.parse(data["at"].to_s).utc + data.fetch("lease_min", DEFAULT_LEASE_MIN).to_i * 60 rescue WorkBoard.now
        [ ref.split("/").last.to_i, { sha: sha, session: data["session"], at: data["at"], lease_min: data["lease_min"],
                                      expires_at: expires.iso8601, expired: expires <= WorkBoard.now } ]
      end
    end

    def claim_ref(number) = "#{CLAIM_NS}/#{@slug}/#{number}"

    def claim_commit(number, session, lease, parent: nil)
      msg = JSON.generate(session: session, item: number, lease_min: lease, at: WorkBoard.now.iso8601, nonce: SecureRandom.hex(4))
      tree = git("hash-object", "-t", "tree", "-w", "/dev/null").strip
      git("commit-tree", tree, *(parent ? [ "-p", parent ] : []), "-m", msg).strip
    end

    # Atomic create-if-absent: --force-with-lease=<ref>: means "the remote ref must not exist".
    def push_claim(number, sha, expect_sha)
      ok, _, err = git("push", "-q", "--force-with-lease=#{claim_ref(number)}:#{expect_sha}", WorkBoard.remote, "#{sha}:#{claim_ref(number)}", ok: true)
      [ ok, err ]
    end

    def delete_claim(number, expect_sha)
      ok, = git("push", "-q", "--force-with-lease=#{claim_ref(number)}:#{expect_sha}", WorkBoard.remote, ":#{claim_ref(number)}", ok: true)
      ok
    end

    # -- labels ----------------------------------------------------------------------------------------------
    def ensure_labels(*names)
      names.flatten.uniq.each do |name|
        color = case name
        when /\Astage:/ then "1d76db"
        when /\Awave:/ then "c5def5"
        when "claimed" then "fbca04"
        when "blocked", "needs-human" then "d93f0b"
        when "epic-root" then "5319e7"
        else "ededed"
        end
        gh("label", "create", name, "--color", color, "--force")
      end
    end

    def current_labels(number)
      gh_json("issue", "view", number.to_s, "--json", "labels").fetch("labels").map { |l| l["name"] }
    end

    # gh rejects removing a label that does not exist in the repository (e.g. `blocked`, which is only created when used),
    # so removals are limited to the labels the issue really carries.
    def edit_labels(number, add: [], remove: [])
      ensure_labels(add) if add.any?
      remove &= current_labels(number) if remove.any?
      args = [ "issue", "edit", number.to_s ]
      args += [ "--add-label", add.join(",") ] if add.any?
      args += [ "--remove-label", remove.join(",") ] if remove.any?
      gh(*args) if args.size > 3
    end

    def post_note(number, type:, session:, text:, stage: nil)
      meta = { type: type, session: session, at: WorkBoard.now.iso8601 }
      meta[:stage] = stage if stage
      Tempfile.create("work-note") do |f|
        f.write("<!-- work-note #{JSON.generate(meta)} -->\n**[#{type}]** #{text}\n")
        f.flush
        gh("issue", "comment", number.to_s, "--body-file", f.path)
      end
    end

    # -- readiness -------------------------------------------------------------------------------------------
    def ready?(item)
      !item.done? && !item.blocked? && (item.blocked_by - done_numbers).empty?
    end

    def conflicting_claims(item, active)
      active.reject { |n, _| n == item.number }.filter_map do |n, _|
        other = items.find { |i| i.number == n }
        n if other && WorkBoard.owns_overlap?(item.owns, other.owns)
      end
    end

    def active_claims = claims.reject { |_, c| c[:expired] }
  end

  def self.remote = ENV.fetch("WORK_REMOTE", "origin")

  # ---- commands ------------------------------------------------------------------------------------------------
  class Cli
    def initialize(argv)
      @argv = argv.dup
    end

    def out(hash, code = 0)
      puts JSON.pretty_generate(hash)
      exit(code)
    end

    def parse(opts_spec)
      opts = {}
      parser = OptionParser.new do |o|
        opts_spec.each do |flag, type|
          key = flag.delete_prefix("--").tr("-", "_").to_sym
          type == :flag ? o.on(flag) { opts[key] = true } : o.on("#{flag} VALUE") { |v| opts[key] = v }
        end
      end
      rest = parser.parse(@argv)
      [ opts, rest ]
    end

    def run
      cmd = @argv.shift
      case cmd
      when "session" then session
      when "epic"
        case @argv.shift
        when "create" then epic_create
        when "done" then epic_done
        else usage
        end
      when "item"
        case @argv.shift
        when "create" then item_create
        when "adopt" then item_adopt
        when "amend" then item_amend
        else usage
        end
      when "validate" then validate
      when "plan-check" then plan_check
      when "plan-apply" then plan_apply
      when "show" then show
      when "status" then status
      when "next" then next_item
      when "reviews" then reviews
      when "mergeable" then mergeable
      when "merge" then merge
      when "claim" then claim
      when "heartbeat" then heartbeat
      when "release" then release
      when "advance" then advance
      when "block" then block
      when "unblock" then unblock
      when "comment" then comment
      when "digest" then digest
      when "reap" then reap
      else usage
      end
    rescue Failure => e
      warn e.message
      out({ error: e.message }, 2)
    end

    def usage = out({ error: "usage: work_board.rb <session|epic create|epic done|item create|item adopt|item amend|validate|status|next|reviews|mergeable|merge|claim|heartbeat|release|advance|block|unblock|comment|digest|reap> ..." }, 2)

    def need(opts, *keys)
      missing = keys.reject { |k| opts[k] }
      out({ error: "missing #{missing.map { |k| "--#{k.to_s.tr('_', '-')}" }.join(', ')}" }, 2) if missing.any?
    end

    # A worker with a typo'd slug must not read "no items" as "all done": every command except validate/plan-apply needs the epic root.
    def board(opts, require_root: true)
      b = Board.new(opts.fetch(:epic))
      raise Failure, "epic #{opts[:epic]} not found (create it with /epic-plan)" if require_root && b.root.nil?

      b
    end
    def body_of(opts) = opts[:body] || (opts[:body_file] ? File.read(opts[:body_file]) : nil)
    def lease_of(opts) = (opts[:lease] || DEFAULT_LEASE_MIN).to_i

    def session
      id = ENV["WORK_SESSION"]
      # One id per Claude Code session: the file fallback below is shared by every session started in this checkout.
      id ||= "#{Socket.gethostname.split('.').first}-#{ENV['CLAUDE_CODE_SESSION_ID'][0, 8]}" if ENV["CLAUDE_CODE_SESSION_ID"].to_s.size >= 8
      unless id
        path = "tmp/epic/session"
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, "#{Socket.gethostname.split('.').first}-#{SecureRandom.hex(3)}") unless File.exist?(path)
        id = File.read(path).strip
      end
      out({ session: id })
    end

    def epic_create
      opts, = parse("--slug" => :v, "--title" => :v, "--body-file" => :v, "--body" => :v)
      need(opts, :slug, :title)
      b = Board.new(opts[:slug])
      b.ensure_labels("epic-root", "epic:#{opts[:slug]}")
      url = create_issue(b, opts[:title], body_of(opts).to_s, [ "epic-root", "epic:#{opts[:slug]}" ])
      out({ epic: opts[:slug], number: url[%r{(\d+)\s*\z}, 1].to_i, url: url })
    end

    # Closes the epic once every item is done: an `announce` note on the root says so, then the root issue is closed. Refuses while
    # an item is open (the reply lists them) and an epic that is already closed.
    def epic_done
      opts, = parse("--epic" => :v, "--session" => :v, "--note" => :v)
      need(opts, :epic, :session)
      b = board(opts)
      out({ error: "epic #{opts[:epic]} is already closed" }, 1) if b.root.closed?
      open = b.items.reject(&:done?)
      if open.any?
        listed = open.map { |i| { number: i.number, title: i.title, stage: i.stage } }
        out({ error: "epic #{opts[:epic]} has #{open.size} item(s) not done", open: listed }, 1)
      end
      text = [ "epic done: all #{b.items.size} items are done", opts[:note] ].compact.join("; ")
      b.post_note(b.root.number, type: "announce", session: opts[:session], text: text)
      b.gh("issue", "close", b.root.number.to_s)
      out({ ok: true, epic: opts[:epic], root: b.root.number, items: b.items.size })
    end

    def create_issue(board, title, body, labels)
      Tempfile.create("work-issue") do |f|
        f.write(body)
        f.flush
        args = [ "issue", "create", "--title", title, "--body-file", f.path ]
        labels.each { |l| args += [ "--label", l ] }
        board.gh(*args).strip
      end
    end

    def item_create
      opts, = parse("--epic" => :v, "--title" => :v, "--body-file" => :v, "--body" => :v, "--wave" => :v, "--owns" => :v,
                    "--blocked-by" => :v, "--stage" => :v, "--priority" => :v)
      need(opts, :epic, :title, :wave, :owns)
      stage = opts[:stage] || "plan"
      out({ error: "unknown stage #{stage}" }, 2) unless STAGES.include?(stage)
      b = board(opts)
      meta = { epic: opts[:epic], wave: opts[:wave].to_i, owns: opts[:owns].split(",").map(&:strip),
               blocked_by: opts[:blocked_by].to_s.split(",").map(&:to_i), priority: opts[:priority].to_i }
      labels = [ "epic:#{opts[:epic]}", "stage:#{stage}", "wave:#{meta[:wave]}" ]
      b.ensure_labels(labels)
      body = "#{body_of(opts)}\n\n<!-- work-item #{JSON.generate(meta)} -->\n"
      url = create_issue(b, opts[:title], body, labels)
      out({ number: url[%r{(\d+)\s*\z}, 1].to_i, url: url, meta: meta })
    end

    # Takes an issue filed outside /epic-plan (a bug, an enhancement) into an epic as an item: appends the contract (Owns, Blocked
    # by, Gates) and the work-item meta block to its body and adds the epic, stage and wave labels. The original text is kept.
    # Gates come from --gates-file (one command per line) or --gates "a;;b". Refuses an issue that is already an item or closed.
    def item_adopt
      opts, rest = parse("--epic" => :v, "--wave" => :v, "--owns" => :v, "--blocked-by" => :v, "--stage" => :v, "--priority" => :v,
                         "--gates-file" => :v, "--gates" => :v)
      need(opts, :epic, :wave, :owns)
      number = rest.first.to_i
      if number.zero?
        out({ error: "usage: item adopt N --epic S --wave W --owns GLOBS (--gates-file F | --gates 'a;;b') [--blocked-by N,M] [--stage plan] [--priority P]" }, 2)
      end
      stage = opts[:stage] || "plan"
      out({ error: "unknown stage #{stage}" }, 2) unless STAGES.include?(stage)
      gates = (opts[:gates_file] ? File.readlines(opts[:gates_file], chomp: true) : opts[:gates].to_s.split(";;")).map(&:strip).reject(&:empty?)
      out({ error: "no gates: pass --gates-file (one command per line) or --gates 'a;;b'" }, 2) if gates.empty?
      b = board(opts)
      issue = Item.new(b.gh_json("issue", "view", number.to_s, "--json", "number,title,state,labels,body"))
      out({ error: "issue ##{number} is already an item of epic #{issue.meta['epic']}" }, 1) unless issue.meta.empty?
      out({ error: "issue ##{number} is closed" }, 1) if issue.closed?
      meta = { epic: opts[:epic], wave: opts[:wave].to_i, owns: opts[:owns].split(",").map(&:strip),
               blocked_by: opts[:blocked_by].to_s.split(",").map(&:to_i), priority: opts[:priority].to_i, adopted: true }
      labels = [ "epic:#{opts[:epic]}", "stage:#{stage}", "wave:#{meta[:wave]}" ]
      b.ensure_labels(labels)
      body = "#{issue.body.rstrip}\n\n#{Plan.adopted_section(meta, gates)}<!-- work-item #{JSON.generate(meta)} -->\n"
      Tempfile.create("work-adopt") do |f|
        f.write(body)
        f.flush
        b.gh("issue", "edit", number.to_s, "--body-file", f.path, "--add-label", labels.join(","))
      end
      out({ number: number, title: issue.title, labels: labels, meta: meta, gates: gates })
    end

    # Amends the contract of an existing item (Owns, Blocked by): meta block and the two body sections, plus an `announce` note on the epic root with the
    # reason and the before/after. --owns / --blocked-by replace, --add-owns / --add-blocked-by append. Refuses a done item, one held
    # by another session and an amendment that makes the plan lint (`validate`) report something it did not report before.
    def item_amend
      opts, rest = parse("--epic" => :v, "--session" => :v, "--owns" => :v, "--add-owns" => :v, "--blocked-by" => :v,
                         "--add-blocked-by" => :v, "--reason" => :v)
      need(opts, :epic, :session, :reason)
      number = rest.first.to_s.match?(/\A#?\d+\z/) ? rest.first.delete("#").to_i : 0
      if number.zero? || %i[owns add_owns blocked_by add_blocked_by].none? { |key| opts[key] }
        out({ error: "usage: item amend N --epic S --session ID [--owns G] [--add-owns G] [--blocked-by N,M] [--add-blocked-by N,M] --reason TXT" }, 2)
      end
      board = board(opts)
      item = board.item(number)
      refuse_amend(board, item, opts[:session])
      owns = (opts[:owns] ? amend_globs(opts[:owns]) : item.owns) + amend_globs(opts[:add_owns])
      blockers = (opts[:blocked_by] ? amend_blockers(opts[:blocked_by]) : item.blocked_by) + amend_blockers(opts[:add_blocked_by])
      owns = owns.uniq
      blockers = blockers.uniq
      added = amend_lint_delta(board, number, owns, blockers)
      out({ error: "amendment refused: the plan lint reports new findings", findings: added }, 1) if added.any?
      out({ number: number, unchanged: true, owns: owns, blocked_by: blockers }) if owns == item.owns && blockers == item.blocked_by

      write_amended_body(board, item, owns, blockers, opts[:session])
      text = "item ##{number} amended: #{opts[:reason]}\nowns: #{item.owns.inspect} -> #{owns.inspect}\nblocked_by: #{item.blocked_by.inspect} -> #{blockers.inspect}"
      was = { owns: item.owns, blocked_by: item.blocked_by }
      begin
        board.post_note(board.root.number, type: "announce", session: opts[:session], text: text)
      rescue Failure => e
        out({ error: "item ##{number} amended but the announce note failed: #{e.message}; post it by hand", number: number, owns: owns,
              blocked_by: blockers, was: was, note: text }, 1)
      end
      out({ number: number, owns: owns, blocked_by: blockers, was: was })
    end

    def refuse_amend(board, item, session)
      out({ error: "item ##{item.number} is done" }, 1) if item.done?
      holder = board.claims[item.number]
      return unless holder && !holder[:expired] && holder[:session] != session

      out({ error: "item ##{item.number} is held by #{holder[:session]}", reason: "held_by_other" }, 1)
    end

    def amend_list(text) = text.to_s.split(",").map(&:strip).reject(&:empty?)

    # Glob text goes into a backtick span of the issue body: a backtick breaks the next parse and a line break could start a section.
    def amend_globs(text)
      amend_list(text).each { |glob| out({ error: "not a glob: #{glob.inspect}" }, 2) if glob.match?(/[`\r\n]|-->/) }
    end

    # Blocker numbers are digits (optionally `#N`): "abc" or "12abc" must not turn into 0 or 12 through to_i.
    def amend_blockers(text)
      amend_list(text).map do |token|
        out({ error: "not an item number: #{token.inspect}" }, 2) unless token.match?(/\A#?\d+\z/)
        token.delete("#").to_i
      end
    end

    # Findings the plan lint reports for the amended plan that it did not report before. Keyed by code, item and the detail without its
    # trailing owns lists: the lists change with the amendment, but the pair (`A and C`) or the blocker the detail names must count as new.
    def amend_lint_delta(board, number, owns, blockers)
      nodes = board.items.map { |i| { id: i.number, wave: i.wave, owns: i.owns, blocked_by: i.blocked_by, stage: i.stage } }
      amended = nodes.map { |node| node[:id] == number ? node.merge(owns: owns, blocked_by: blockers) : node }
      key = ->(finding) { [ finding[:code], finding[:item], finding[:detail].to_s.sub(/ \(.*\)\z/m, "") ] }
      known = Hash.new(0).merge!(Plan.check(nodes).map(&key).tally)
      Plan.check(amended).select { |finding| (known[key.call(finding)] -= 1).negative? }
    end

    # Rewrites the issue from a fresh read (a body edited since the item was listed is not overwritten blindly).
    def write_amended_body(board, item, owns, blockers, session)
      fresh = Item.new(board.gh_json("issue", "view", item.number.to_s, "--json", "number,title,state,labels,body"))
      raise Failure, "item ##{item.number} changed while it was being amended, run it again" unless fresh.body == item.body

      refuse_amend(board, fresh, session)

      Tempfile.create("work-amend") do |f|
        f.write(item.with_contract(owns: owns, blocked_by: blockers))
        f.flush
        board.gh("issue", "edit", item.number.to_s, "--body-file", f.path)
      end
    end

    def validate
      opts, = parse("--epic" => :v)
      need(opts, :epic)
      b = board(opts, require_root: false)
      findings = []
      findings << { code: "NO_ROOT", item: nil, detail: "epic #{opts[:epic]} has no epic-root issue" } unless b.root
      its = b.items
      findings += Plan.check(its.map { |i| { id: i.number, wave: i.wave, owns: i.owns, blocked_by: i.blocked_by, stage: i.stage } })
      out({ epic: opts[:epic], items: its.size, pass: findings.empty?, findings: findings }, findings.empty? ? 0 : 1)
    end

    def read_plan(opts)
      need(opts, :file)
      JSON.parse(File.read(opts[:file]))
    rescue JSON::ParserError, Errno::ENOENT => e
      out({ error: "cannot read plan: #{e.message}" }, 2)
    end

    def plan_check
      opts, = parse("--file" => :v)
      findings = Plan.check_plan_file(read_plan(opts))
      out({ pass: findings.empty?, findings: findings }, findings.empty? ? 0 : 1)
    end

    def plan_apply
      opts, = parse("--file" => :v)
      plan = read_plan(opts)
      findings = Plan.check_plan_file(plan)
      out({ error: "plan has findings, run plan-check", findings: findings }, 1) if findings.any?
      slug = plan.dig("epic", "slug")
      b = Board.new(slug)
      out({ error: "epic #{slug} already has issues; plan-apply only creates new epics" }, 1) if b.all_issues.any?

      b.ensure_labels("epic-root", "epic:#{slug}")
      root = create_issue(b, plan.dig("epic", "title"), plan.dig("epic", "body").to_s, [ "epic-root", "epic:#{slug}" ])
      numbers = {}
      plan["items"].each_with_index.sort_by { |i, idx| [ i["wave"].to_i, idx ] }.each do |i, _|
        meta = { epic: slug, wave: i["wave"].to_i, owns: i["owns"], blocked_by: Array(i["blocked_by"]).map { |k| numbers.fetch(k) }, priority: i["priority"].to_i, key: i["key"] }
        stage = i["stage"] || "plan"
        labels = [ "epic:#{slug}", "stage:#{stage}", "wave:#{meta[:wave]}" ]
        b.ensure_labels(labels)
        body = "#{Plan.body(i, numbers)}\n<!-- work-item #{JSON.generate(meta)} -->\n"
        numbers[i["key"]] = create_issue(b, i["title"], body, labels)[%r{(\d+)\s*\z}, 1].to_i
      end
      out({ epic: slug, root: root[%r{(\d+)\s*\z}, 1].to_i, items: numbers })
    end

    def show
      opts, rest = parse("--epic" => :v)
      need(opts, :epic)
      b = board(opts)
      item = b.item(rest.first.to_i)
      raw = b.gh_json("issue", "view", item.number.to_s, "--json", "body,comments")
      notes = b.comments(item.number).select { |c| c[:note] }.map { |c| c.slice(:type, :session, :at, :body) }
      claim = b.claims[item.number]
      out(item.summary.merge(gates: item.gates, body: raw["body"].to_s.sub(META, "").strip, notes: notes, holder: claim && !claim[:expired] ? claim[:session] : nil))
    end

    def status
      opts, = parse("--epic" => :v)
      need(opts, :epic)
      b = board(opts)
      claims = b.claims
      rows = b.items.sort_by { |i| [ i.wave, i.number ] }.map do |i|
        c = claims[i.number]
        state = if i.done? then "done"
        elsif i.blocked? then "blocked"
        elsif c && !c[:expired] then "in-progress"
        elsif b.ready?(i) && i.stage == "review" then "in-review"
        elsif b.ready?(i) then "ready"
        else "waiting"
        end
        i.summary.merge(state: state, holder: c && !c[:expired] ? c[:session] : nil, lease_expires_at: c&.dig(:expires_at), stale_claim: c&.dig(:expired) || false)
      end
      out({ epic: opts[:epic], counts: rows.group_by { |r| r[:state] }.transform_values(&:size), items: rows })
    end

    def next_item
      opts, = parse("--epic" => :v, "--session" => :v, "--stage" => :v)
      need(opts, :epic)
      b = board(opts)
      active = b.active_claims
      stages = opts[:stage]&.split(",")
      pool = b.items.reject(&:done?)
      # Items in review wait for a human merge; they are only offered when the worker asks for that stage (see `reviews`).
      candidates = pool.select { |i| b.ready?(i) && !active.key?(i.number) && (stages.nil? ? i.stage != "review" : stages.include?(i.stage)) }
      candidates = candidates.reject { |i| b.conflicting_claims(i, active).any? }
      pick = candidates.min_by { |i| [ i.wave, -i.priority, i.number ] }
      return out({ item: pick.summary }) if pick

      awaiting = pool.select { |i| i.stage == "review" && !active.key?(i.number) }
      reason = if pool.empty? then "all_done"
      elsif stages.nil? && awaiting.any? && pool.none? { |i| i.stage != "review" && b.ready?(i) && !active.key?(i.number) } then "awaiting_merge"
      elsif pool.any? { |i| b.ready?(i) && !active.key?(i.number) } then "filtered" # ready items exist but --stage or an owns overlap excluded them
      elsif pool.any? { |i| active.key?(i.number) } then "claimed_by_others"
      elsif pool.any?(&:blocked?) then "needs_human"
      else "waiting_on_dependencies"
      end
      out({ item: nil, reason: reason, remaining: pool.map(&:number), **(reason == "awaiting_merge" ? { awaiting_merge: awaiting.map(&:number) } : {}) })
    end

    # Items in review with the state of their PR. `merged` items are ready for the worker to verify the gates on main and advance to done.
    def reviews
      opts, = parse("--epic" => :v, "--item" => :v)
      need(opts, :epic)
      b = board(opts)
      rows = review_rows(b, opts[:item])
      out({ epic: opts[:epic], reviews: rows, merged: rows.select { |r| r[:verdict] == "merged" }.map { |r| r[:number] } })
    end

    def review_rows(b, only = nil)
      claims = b.claims
      pool = only ? [ b.item(only.to_i) ] : b.items.select { |i| i.stage == "review" && !i.done? }
      prs = pool.empty? ? [] : b.pull_requests
      pool.map do |i|
        pr = b.pull_request_for(i.number, prs)
        verdict = if pr.nil? then "no_pr"
        elsif pr["state"] == "MERGED" then "merged"
        elsif pr["state"] == "OPEN" then "open"
        else "closed_unmerged"
        end
        holder = claims[i.number]
        { number: i.number, title: i.title, stage: i.stage, wave: i.wave, verdict: verdict, gates: i.gates,
          pr: pr && { number: pr["number"], state: pr["state"], url: pr["url"] }, holder: holder && !holder[:expired] ? holder[:session] : nil }
      end
    end

    # `reviews` plus the merge policy on every open PR. Cheap calls only for the base branch (one check-runs read); per open PR
    # one `pr view`, one compare, and a second compare only when the PR is behind the base.
    def mergeable
      opts, = parse("--epic" => :v, "--item" => :v)
      need(opts, :epic)
      b = board(opts)
      rows, base = judge_rows(b, opts[:item])
      out({ epic: opts[:epic], base: base, items: rows, ready: rows.select { |r| r[:verdict] == "ready" }.map { |r| r[:number] } })
    end

    def judge_rows(b, only = nil)
      rows = review_rows(b, only)
      base_checks = b.base_check_runs
      base_sha = base_checks.first&.dig("head_sha")
      rows.each do |row|
        next unless row[:verdict] == "open"

        pr = b.pull_request(row[:pr][:number])
        cmp = b.compare(pr["baseRefName"] || WorkBoard.base, pr["headRefOid"])
        base_sha ||= cmp.dig("base_commit", "sha")
        behind = cmp.fetch("behind_by", 0).to_i
        pr_files = Array(cmp["files"]).map { |f| f["filename"] }
        base_files = behind.positive? ? Array(b.compare(cmp.dig("merge_base_commit", "sha"), pr["baseRefName"] || WorkBoard.base)["files"]).map { |f| f["filename"] } : []
        row[:audited] = b.audited?(row[:number])
        row[:pr].merge!(head: pr["headRefOid"], branch: pr["headRefName"], base: pr["baseRefName"], draft: pr["isDraft"], mergeable: pr["mergeable"], merge_state: pr["mergeStateStatus"])
        row.merge!(MergePolicy.judge(pr: pr, audited: row[:audited], base_checks: base_checks, behind_by: behind, pr_files: pr_files, base_files: base_files))
      end
      base = { branch: WorkBoard.base, sha: base_sha, failing: MergePolicy.failing(base_checks),
               checks: base_checks.map { |c| { name: c["name"], status: c["status"], conclusion: c["conclusion"], url: c["html_url"] } } }
      [ rows, base ]
    end

    # The one place a PR of the board is merged. Re-judges right before merging and pins the head it judged.
    def merge
      opts, rest = parse("--epic" => :v, "--session" => :v, "--method" => :v, "--keep-branch" => :flag)
      need(opts, :epic, :session)
      method = opts[:method] || "squash"
      out({ error: "method must be one of #{MERGE_METHODS.join(', ')}" }, 2) unless MERGE_METHODS.include?(method)
      b = board(opts)
      number = rest.first.to_i
      row, = judge_rows(b, number)
      row = row.first
      out({ ok: false, reason: "held", holder: row[:holder], item: row }, 1) if row[:holder]
      out({ ok: false, reason: row[:verdict], item: row }, 1) unless row[:verdict] == "ready"

      b.merge_pull_request(row[:pr][:number], method: method, head: row[:pr][:head])
      merged = b.pull_request(row[:pr][:number])
      sha = merged.dig("mergeCommit", "oid")
      branch_deleted = opts[:keep_branch] ? false : b.delete_remote_branch(row[:pr][:branch])
      b.post_note(number, type: "merge-log", session: opts[:session], stage: row[:stage],
                  text: "PR ##{row[:pr][:number]} merged into #{WorkBoard.base} (#{method}#{sha ? ", #{sha[0, 10]}" : ''}); the merge sweep verifies the Gates on #{WorkBoard.base} and advances to done")
      out({ ok: true, number: number, pr: row[:pr][:number], method: method, state: merged["state"], merge_commit: sha, branch: row[:pr][:branch], branch_deleted: branch_deleted })
    end

    def claim
      opts, rest = parse("--epic" => :v, "--session" => :v, "--lease" => :v)
      need(opts, :epic, :session)
      number = rest.first.to_i
      b = board(opts)
      item = b.item(number)
      out({ claimed: false, reason: "not_ready", detail: "done, blocked or waiting on #{(item.blocked_by - b.done_numbers).inspect}" }, 1) unless b.ready?(item)
      claims = b.claims
      current = claims[number]
      if current && !current[:expired]
        if current[:session] == opts[:session]
          return refresh(b, number, opts, current, resumed: true)
        end

        out({ claimed: false, reason: "held", holder: current[:session], lease_expires_at: current[:expires_at] }, 1)
      end
      clash = b.conflicting_claims(item, claims.reject { |_, c| c[:expired] })
      out({ claimed: false, reason: "owns_overlap", with: clash }, 1) if clash.any?

      b.delete_claim(number, current[:sha]) if current # expired holder is reaped atomically
      sha = b.claim_commit(number, opts[:session], lease_of(opts))
      ok, err = b.push_claim(number, sha, "")
      unless ok
        holder = b.claims[number]
        out({ claimed: false, reason: "held", holder: holder&.dig(:session), detail: err.strip.lines.last }, 1)
      end
      b.edit_labels(number, add: [ "claimed" ])
      out({ claimed: true, number: number, session: opts[:session], stage: item.stage, owns: item.owns, lease_expires_at: (WorkBoard.now + lease_of(opts) * 60).iso8601 })
    end

    def refresh(b, number, opts, current, resumed: false)
      sha = b.claim_commit(number, opts[:session], lease_of(opts), parent: current[:sha])
      ok, err = b.push_claim(number, sha, current[:sha])
      out({ claimed: false, reason: "lost_lease", detail: err.strip.lines.last }, 1) unless ok
      out({ claimed: true, resumed: resumed, number: number, session: opts[:session], lease_expires_at: (WorkBoard.now + lease_of(opts) * 60).iso8601 })
    end

    def held_by(b, number, session)
      current = b.claims[number]
      out({ ok: false, reason: "not_held", detail: "no claim on ##{number}" }, 1) unless current
      out({ ok: false, reason: "held_by_other", holder: current[:session] }, 1) unless current[:session] == session
      current
    end

    def heartbeat
      opts, rest = parse("--epic" => :v, "--session" => :v, "--lease" => :v)
      need(opts, :epic, :session)
      b = board(opts)
      refresh(b, rest.first.to_i, opts, held_by(b, rest.first.to_i, opts[:session]))
    end

    def release
      opts, rest = parse("--epic" => :v, "--session" => :v, "--force" => :flag)
      need(opts, :epic)
      need(opts, :session) unless opts[:force]
      b = board(opts)
      number = rest.first.to_i
      current = opts[:force] ? (b.claims[number] || out({ ok: false, reason: "not_held" }, 1)) : held_by(b, number, opts[:session])
      out({ ok: false, reason: "lost_lease" }, 1) unless b.delete_claim(number, current[:sha])
      b.edit_labels(number, remove: [ "claimed" ])
      out({ ok: true, released: number, was_held_by: current[:session], forced: opts[:force] || false })
    end

    def advance
      opts, rest = parse("--epic" => :v, "--session" => :v, "--stage" => :v, "--keep" => :flag, "--note" => :v, "--audit-receipt" => :v)
      need(opts, :epic, :session, :stage)
      out({ error: "unknown stage #{opts[:stage]}" }, 2) unless STAGES.include?(opts[:stage])
      b = board(opts)
      number = rest.first.to_i
      current = held_by(b, number, opts[:session])
      item = b.item(number)
      note = opts[:note]
      if opts[:stage] == "review"
        # The audit bar is checked by a script on the code in front of us, never taken from the agent's word (epic-flow R10).
        verdict = AuditReceipt.check(opts[:audit_receipt].to_s, min: AUDIT_MIN)
        out({ ok: false, reason: "audit_not_passed", reasons: verdict["reasons"], bar: "all five scores >= #{AUDIT_MIN}, verdict PASS, 0 mandatory open, receipt for the current code" }, 1) unless verdict["ok"]
        note = [ verdict["summary"], note ].compact.join("; ")
      end
      b.post_note(number, type: "stage-log", session: opts[:session], stage: item.stage, text: "#{item.stage} -> #{opts[:stage]}#{note ? ": #{note}" : ''}")
      b.edit_labels(number, add: [ "stage:#{opts[:stage]}" ], remove: [ "stage:#{item.stage}" ])
      b.gh("issue", "close", number.to_s) if opts[:stage] == "done"
      if opts[:keep] && opts[:stage] != "done"
        return refresh(b, number, opts, current)
      end

      b.delete_claim(number, current[:sha])
      b.edit_labels(number, remove: [ "claimed" ])
      out({ ok: true, number: number, stage: opts[:stage], released: true })
    end

    def block
      opts, rest = parse("--epic" => :v, "--session" => :v, "--reason" => :v)
      need(opts, :epic, :session, :reason)
      b = board(opts)
      number = rest.first.to_i
      current = held_by(b, number, opts[:session])
      b.post_note(number, type: "blocker", session: opts[:session], text: opts[:reason])
      b.delete_claim(number, current[:sha])
      b.edit_labels(number, add: [ "needs-human" ], remove: [ "claimed" ])
      out({ ok: true, number: number, blocked: true })
    end

    def unblock
      opts, rest = parse("--epic" => :v)
      need(opts, :epic)
      board(opts).edit_labels(rest.first.to_i, remove: BLOCKING_LABELS)
      out({ ok: true, number: rest.first.to_i })
    end

    def comment
      opts, rest = parse("--epic" => :v, "--session" => :v, "--type" => :v, "--body" => :v, "--body-file" => :v)
      need(opts, :epic, :session, :type)
      out({ error: "type must be one of #{NOTE_TYPES.join(', ')}" }, 2) unless NOTE_TYPES.include?(opts[:type])
      text = body_of(opts)
      out({ error: "empty body" }, 2) if text.to_s.strip.empty?
      number = rest.first.to_i
      b = board(opts)
      b.item(number) unless b.root&.number == number
      b.post_note(number, type: opts[:type], session: opts[:session], text: text.strip)
      out({ ok: true, number: number, type: opts[:type] })
    end

    # What a worker must read when it takes an item: epic-thread notes + notes on the item + shared/handoff notes of its blockers.
    def digest
      opts, = parse("--epic" => :v, "--item" => :v, "--format" => :v)
      need(opts, :epic)
      b = board(opts)
      sources = []
      sources << [ b.root.number, %w[shared lesson announce blocker] ] if b.root
      if opts[:item]
        item = b.item(opts[:item].to_i)
        sources << [ item.number, %w[handoff blocker shared lesson] ]
        item.blocked_by.each { |d| sources << [ d, %w[shared handoff] ] }
      end
      notes = sources.flat_map { |n, types| b.comments(n).select { |c| c[:note] && types.include?(c[:type]) } }
      notes = notes.sort_by { |c| c[:at].to_s }
      notes = notes.map { |c| c.slice(:number, :type, :session, :at, :body) }
      if opts[:format] == "md"
        puts(notes.map { |c| "### [#{c[:type]}] ##{c[:number]} by #{c[:session]} (#{c[:at]})\n#{c[:body]}\n" }.join("\n"))
        exit 0
      end
      out({ epic: opts[:epic], item: opts[:item]&.to_i, notes: notes })
    end

    def reap
      opts, = parse("--epic" => :v)
      need(opts, :epic)
      b = board(opts)
      freed = b.claims.select { |_, c| c[:expired] }.filter_map do |n, c|
        next unless b.delete_claim(n, c[:sha])

        b.edit_labels(n, remove: [ "claimed" ])
        { number: n, was_held_by: c[:session] }
      end
      out({ freed: freed })
    end
  end
end

WorkBoard::Cli.new(ARGV).run if $PROGRAM_NAME == __FILE__

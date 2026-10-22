#!/usr/bin/env ruby
# frozen_string_literal: true

# Machine-readable receipt of an /audit-feature run, so a script (not the agent's word) decides whether the
# audit bar was met and whether it covers the code that is about to be handed over.
#
#   audit_receipt.rb write --scores architecture=9,clean_code=8,scalability=8,security=9,testability=8 \
#                          --verdict PASS --mandatory-open 0 --iterations 2 --out tmp/audit/<slug>/scorecard.json
#   audit_receipt.rb check PATH [--min 8] [--dir DIR]     # JSON { ok, reasons, summary }; exit 0 ok, 1 not ok, 2 error
#   audit_receipt.rb tree [--dir DIR]                      # fingerprint of the code as it is now (see below)
#
# The fingerprint is the git tree of the working directory contents (tracked + untracked, honouring .gitignore), computed
# in a throw-away index. It equals `HEAD^{tree}` once the same content is committed, so a receipt written before the
# worker commits is still valid after the commit and is stale after any later edit.
# What this proves: the numbers pass the bar and belong to this exact code. It cannot prove the numbers were copied
# honestly from the House scorecard; that is why the audit report is persisted next to the receipt.

require "json"
require "optparse"
require "open3"
require "tmpdir"
require "time"
require "fileutils"

module AuditReceipt
  SCORES = %w[architecture clean_code scalability security testability].freeze
  DEFAULT_MIN = 8

  class Error < StandardError; end

  module_function

  def tree(dir = Dir.pwd)
    Dir.mktmpdir("audit-index") do |tmp|
      env = { "GIT_INDEX_FILE" => File.join(tmp, "index") }
      git(env, dir, "read-tree", "HEAD") if system("git", "-C", dir, "rev-parse", "--verify", "-q", "HEAD", out: File::NULL, err: File::NULL)
      git(env, dir, "add", "-A")
      git(env, dir, "write-tree").strip
    end
  end

  def write(path, scores:, verdict:, mandatory_open:, iterations:, dir: Dir.pwd, now: Time.now.utc)
    unknown = scores.keys - SCORES
    missing = SCORES - scores.keys
    raise Error, "unknown score(s): #{unknown.join(', ')}" if unknown.any?
    raise Error, "missing score(s): #{missing.join(', ')}" if missing.any?

    receipt = {
      "scores" => scores, "min" => scores.values.min, "verdict" => verdict,
      "mandatory_open" => mandatory_open, "iterations" => iterations,
      "tree" => tree(dir), "at" => now.iso8601
    }
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, JSON.pretty_generate(receipt))
    receipt
  end

  # reasons is empty when the receipt passes. Each reason names the number and the bar so the worker knows what to fix.
  def check(path, min: DEFAULT_MIN, dir: Dir.pwd)
    return result(false, [ "no receipt at #{path}" ]) unless File.file?(path)

    data = begin
      JSON.parse(File.read(path))
    rescue JSON::ParserError
      return result(false, [ "receipt #{path} is not valid JSON" ])
    end
    scores = data["scores"].is_a?(Hash) ? data["scores"] : {}
    reasons = []
    SCORES.each do |name|
      value = scores[name]
      if !value.is_a?(Numeric) || value.negative? || value > 10 then reasons << "#{name} score is missing or not a number between 0 and 10"
      elsif value < min then reasons << "#{name}=#{value} is below #{min}"
      end
    end
    reasons << "verdict is #{data['verdict'].inspect}, not PASS" unless data["verdict"] == "PASS"
    reasons << "#{data['mandatory_open'].inspect} mandatory finding(s) still open" unless data["mandatory_open"] == 0
    current = tree(dir)
    reasons << "stale receipt: it audited tree #{data['tree'].to_s[0, 10]}, the code now is #{current[0, 10]}; audit again" unless data["tree"] == current
    result(reasons.empty?, reasons, summary(data))
  end

  def summary(data)
    scores = data["scores"].is_a?(Hash) ? data["scores"] : {}
    "audit min=#{scores.values.grep(Numeric).min} verdict=#{data['verdict']} iterations=#{data['iterations']} tree=#{data['tree'].to_s[0, 10]}"
  end

  def result(ok, reasons, summary = nil) = { "ok" => ok, "reasons" => reasons, "summary" => summary }

  def git(env, dir, *args)
    out, err, status = Open3.capture3(env, "git", "-C", dir, *args)
    raise Error, "git #{args.first} failed: #{err.strip}" unless status.success?

    out
  end
end

if $PROGRAM_NAME == __FILE__
  command = ARGV.shift
  opts = { min: AuditReceipt::DEFAULT_MIN, dir: Dir.pwd, mandatory_open: 0, iterations: 0 }
  parser = OptionParser.new do |o|
    o.on("--scores LIST") { |v| opts[:scores] = v.split(",").to_h { |pair| k, n = pair.split("="); [ k, Float(n).then { |f| f == f.to_i ? f.to_i : f } ] } }
    o.on("--verdict V") { |v| opts[:verdict] = v }
    o.on("--mandatory-open N", Integer) { |v| opts[:mandatory_open] = v }
    o.on("--iterations N", Integer) { |v| opts[:iterations] = v }
    o.on("--out PATH") { |v| opts[:out] = v }
    o.on("--min N", Float) { |v| opts[:min] = v }
    o.on("--dir DIR") { |v| opts[:dir] = v }
  end
  rest = parser.parse(ARGV)
  begin
    case command
    when "write"
      abort("usage: write --scores a=9,... --verdict PASS --out PATH") unless opts[:scores] && opts[:verdict] && opts[:out]
      puts JSON.pretty_generate(AuditReceipt.write(opts[:out], scores: opts[:scores], verdict: opts[:verdict], mandatory_open: opts[:mandatory_open], iterations: opts[:iterations], dir: opts[:dir]))
    when "check"
      abort("usage: check PATH [--min 8]") unless rest.first
      result = AuditReceipt.check(rest.first, min: opts[:min], dir: opts[:dir])
      puts JSON.pretty_generate(result)
      exit(result["ok"] ? 0 : 1)
    when "tree" then puts AuditReceipt.tree(opts[:dir])
    else abort("usage: audit_receipt.rb write|check|tree")
    end
  rescue AuditReceipt::Error, ArgumentError => e
    warn(e.message)
    exit 2
  end
end

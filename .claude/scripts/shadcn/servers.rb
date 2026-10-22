#!/usr/bin/env ruby
# frozen_string_literal: true

# Starts/stops the two dev servers the parity runs need (Rails = the dummy app of the gem, which serves the Phlex port; Vite = the React
# oracle) on FREE ports.
# Fixed ports are fragile on a developer machine (another project's puma on :3000 is common), so this picks free ones,
# records them in layout.rb SERVERS_FILE (which parity_run.mjs reads by default) and only ever reuses servers it started.
#
#   ruby .claude/scripts/shadcn/servers.rb start [--rails-port N] [--vite-port N] [--restart]
#   ruby .claude/scripts/shadcn/servers.rb status        # JSON; exit 1 unless both answer
#   ruby .claude/scripts/shadcn/servers.rb stop
#   ruby .claude/scripts/shadcn/servers.rb ports [--rails-port N] [--vite-port N]   # only print the ports it would pick
#
# Rails answers on http://localhost:PORT/up, Vite on http://localhost:PORT/ . Logs: <TMP_DIR>/{rails,vite}.log.
# The dummy app (layout.rb DUMMY_DIR) is DB-less and mounts the gem through its engine only; it runs under its own Gemfile
# (BUNDLE_GEMFILE), so nothing of the host application is booted.

require_relative "layout"
require "json"
require "net/http"
require "optparse"
require "socket"
require "fileutils"
require "bundler"

STATE = ShadcnLayout::SERVERS_FILE
TMP_DIR = ShadcnLayout::TMP_DIR
DEFAULTS = { rails: 3055, vite: 5177 }.freeze

def port_free?(port)
  %w[127.0.0.1 ::1].all? do |host|
    TCPServer.new(host, port).close
    true
  rescue Errno::EADDRINUSE, Errno::EACCES
    false
  rescue SocketError, Errno::EADDRNOTAVAIL
    true # the address family is not available here: nothing can be listening on it
  end
end

def pick_port(start, taken = [])
  (start..start + 200).find { |p| !taken.include?(p) && port_free?(p) } || abort("no free port near #{start}")
end

def healthy?(url)
  res = Net::HTTP.get_response(URI(url))
  res.code.to_i.between?(200, 399)
rescue StandardError
  false
end

def load_state = File.exist?(STATE) ? JSON.parse(File.read(STATE)) : nil

def alive?(pid)
  Process.kill(0, pid)
  true
rescue Errno::ESRCH, Errno::EPERM
  false
end

def status
  s = load_state
  return { rails_ok: false, vite_ok: false, running: false } unless s

  rails_ok = alive?(s.dig("rails", "pid")) && healthy?("#{s.dig('rails', 'url')}/up")
  vite_ok = alive?(s.dig("vite", "pid")) && healthy?("#{s.dig('vite', 'url')}/")
  { rails_url: s.dig("rails", "url"), vite_url: s.dig("vite", "url"), rails_ok: rails_ok, vite_ok: vite_ok, running: rails_ok && vite_ok }
end

def stop
  s = load_state
  return puts(JSON.generate(stopped: false, reason: "no servers.json")) unless s

  %w[rails vite].each do |k|
    pid = s.dig(k, "pid")
    next unless pid && alive?(pid)

    begin
      Process.kill("TERM", -Process.getpgid(pid)) # whole group: npm/puma children included
    rescue Errno::ESRCH, Errno::EPERM
      Process.kill("TERM", pid) rescue nil
    end
  end
  sleep 1
  FileUtils.rm_f(STATE)
  puts JSON.generate(stopped: true)
end

def wait_for(url, seconds)
  deadline = Time.now + seconds
  sleep 0.5 until healthy?(url) || Time.now > deadline
  healthy?(url)
end

# The dummy app runs under its own bundle: the host's environment (BUNDLE_GEMFILE, RUBYOPT, RAILS_ENV...) must not leak into it.
def dummy_env
  dummy = File.expand_path(ShadcnLayout::DUMMY_DIR)
  { "BUNDLE_GEMFILE" => File.join(dummy, "Gemfile"), "RAILS_ENV" => "development", "OBJC_DISABLE_INITIALIZE_FORK_SAFETY" => "YES",
    "SHADCN_PARITY_BREAK_FLAG" => File.expand_path("#{TMP_DIR}/_harness/break-probe") }
end

def spawn_dummy(port)
  log = File.expand_path("#{TMP_DIR}/rails.log")
  Bundler.with_unbundled_env do
    # One-shot Tailwind build (the engine bundle + the scenarios/renderer @source), then the server.
    built = system(dummy_env, "bin/rails", "tailwindcss:build", chdir: ShadcnLayout::DUMMY_DIR, out: log, err: [:child, :out])
    abort("tailwindcss:build failed in #{ShadcnLayout::DUMMY_DIR} (see #{log})") unless built
    Process.spawn(dummy_env, "bin/rails", "server", "-p", port.to_s, "-b", "127.0.0.1", "-P", File.expand_path("#{TMP_DIR}/shadcn-parity.pid"),
                  chdir: ShadcnLayout::DUMMY_DIR, out: [log, "a"], err: [:child, :out], pgroup: true)
  end
end

def start(opts)
  stop if opts[:restart]
  cur = status
  return puts(JSON.generate(cur.merge(reused: true))) if cur[:running]

  FileUtils.mkdir_p(TMP_DIR)
  FileUtils.mkdir_p(File.dirname(STATE))
  rails_port = opts[:rails_port] || pick_port(DEFAULTS[:rails])
  vite_port = opts[:vite_port] || pick_port(DEFAULTS[:vite], [rails_port])

  rails_url = "http://localhost:#{rails_port}"
  vite_url = "http://localhost:#{vite_port}"
  rails_pid = spawn_dummy(rails_port)
  vite_pid = begin
    Process.spawn("npm", "run", "dev", "--", "--port", vite_port.to_s, "--strictPort", "--host", "127.0.0.1",
                  chdir: ShadcnLayout::CATALOG_DIR, out: File.expand_path("#{TMP_DIR}/vite.log"), err: [:child, :out], pgroup: true)
  rescue SystemCallError
    begin
      Process.kill("TERM", -Process.getpgid(rails_pid)) # a failed Vite spawn must not orphan the dummy's Rails
    rescue SystemCallError
      nil
    end
    raise
  end
  [rails_pid, vite_pid].each { |pid| Process.detach(pid) }

  File.write(STATE, JSON.pretty_generate(rails: { port: rails_port, url: rails_url, pid: rails_pid }, vite: { port: vite_port, url: vite_url, pid: vite_pid }, started_at: Time.now.utc.iso8601))

  rails_ok = wait_for("#{rails_url}/up", 120)
  vite_ok = wait_for("#{vite_url}/", 60)
  result = { rails_url: rails_url, vite_url: vite_url, rails_ok: rails_ok, vite_ok: vite_ok, running: rails_ok && vite_ok, reused: false }
  warn "rails log: #{TMP_DIR}/rails.log" unless rails_ok
  warn "vite log: #{TMP_DIR}/vite.log" unless vite_ok
  puts JSON.pretty_generate(result)
  exit(result[:running] ? 0 : 1)
end

cmd = ARGV.shift
opts = {}
OptionParser.new do |o|
  o.on("--rails-port N", Integer) { |v| opts[:rails_port] = v }
  o.on("--vite-port N", Integer) { |v| opts[:vite_port] = v }
  o.on("--restart") { opts[:restart] = true }
end.parse!

case cmd
when "start" then start(opts)
when "stop" then stop
when "status"
  st = status
  puts JSON.pretty_generate(st)
  exit(st[:running] ? 0 : 1)
when "ports"
  rails = opts[:rails_port] || pick_port(DEFAULTS[:rails])
  puts JSON.generate(rails: rails, vite: opts[:vite_port] || pick_port(DEFAULTS[:vite], [rails]))
else abort("usage: start | stop | status | ports")
end

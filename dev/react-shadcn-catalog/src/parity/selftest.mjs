// _harness self-test: proves both sides of the parity harness before any component uses them.
//   cd <catalog dir> && node src/parity/selftest.mjs      -> <TMP_DIR>/_harness/selftest.json, exit 1 on any failed check
// Checks: servers.rb status; identical probes -> parity_run exit 0; deliberately broken Phlex probe (extra class, via the
// tmp/shadcn-port/_harness/break-probe flag file read by ShadcnParity::Probe) -> exit 1 with a CLASS diff; the compound
// probe through ?dx=helpers -> exit 0; animation determinism (5 clean runs, a duration mismatch still fails); unknown scenarios on both sides -> HTTP_STATUS / PARITY_ERROR / EMPTY_RENDER.
import { execFileSync, spawnSync } from "node:child_process"
import fs from "node:fs"
import os from "node:os"
import path from "node:path"

// Repo root = the git checkout; every other path comes from layout.rb (the one place that knows the dev-kit layout).
const ROOT = execFileSync("git", ["rev-parse", "--show-toplevel"], { encoding: "utf8" }).trim()
const LAYOUT = JSON.parse(execFileSync("ruby", [path.join(ROOT, ".claude/scripts/shadcn/layout.rb"), "--json"], { encoding: "utf8", cwd: ROOT }))
const RUNNER = path.join(ROOT, ".claude/scripts/shadcn/parity_run.mjs")
const FLAG = path.join(ROOT, LAYOUT.TMP_DIR, "_harness/break-probe")
const recorded = JSON.parse(fs.readFileSync(path.join(ROOT, LAYOUT.SERVERS_FILE), "utf8"))
const out = { checks: {}, at: new Date().toISOString() }

const run = (extra, opts = {}) => {
  const r = spawnSync("node", [RUNNER, "--component", "_harness", ...extra], { cwd: process.cwd(), encoding: "utf8", env: process.env, ...opts })
  let report = null
  try { report = JSON.parse(r.stdout) } catch { /* runner crashed */ }
  return { status: r.status, report, stderr: r.stderr.slice(0, 500) }
}
const kinds = (r) => [...new Set((r.report?.diffs ?? []).map((d) => d.kind))]
const record = (name, pass, detail) => { out.checks[name] = { pass, ...detail } }

const servers = spawnSync("ruby", [path.join(ROOT, ".claude/scripts/shadcn/servers.rb"), "status"], { cwd: ROOT, encoding: "utf8" })
record("servers_status", servers.status === 0, { output: servers.stdout.trim().replace(/\s+/g, " ") })

const clean = run([])
record("identical_probes_exit_0", clean.status === 0, { exit: clean.status, scenarios: clean.report?.scenarios, diffs: clean.report?.total_diffs })
out.identical = { exit: clean.status, total_diffs: clean.report?.total_diffs }

fs.mkdirSync(path.dirname(FLAG), { recursive: true })
fs.writeFileSync(FLAG, "extra class on the Phlex probe\n")
let broken
try { broken = run([]) } finally { fs.rmSync(FLAG, { force: true }) }
record("broken_probe_exit_1", broken.status === 1 && kinds(broken).includes("CLASS"), { exit: broken.status, kinds: kinds(broken) })
out.broken = { exit: broken.status, kinds: kinds(broken) }

const dx = run(["--dx", "helpers"])
record("dx_helpers_exit_0", dx.status === 0, { exit: dx.status, diffs: dx.report?.total_diffs })

// Animation determinism (animations: true scenarios are sampled at logical time): 5 identical runs -> 0 diffs; a 200ms vs 300ms
// transition (Phlex side renders anim-transition-slow via --phlex-scenario) must still produce a STYLE diff at the 75ms sample.
const animRuns = Array.from({ length: 5 }, () => run(["--only", "anim-transition,anim-keyframes"]).report?.total_diffs)
record("animations_deterministic_5x", animRuns.every((n) => n === 0), { diffs: animRuns })
const slow = run(["--only", "anim-transition", "--phlex-scenario", "anim-transition-slow"])
record("animation_duration_mismatch_fails", slow.status === 1 && kinds(slow).includes("STYLE"), { exit: slow.status, kinds: kinds(slow) })

// Per-step `snapshot: false`: the 75ms wait of snap-skip (200ms vs 300ms transition on Phlex via --phlex-scenario) would be a STYLE diff;
// with the flag that step is not compared, and the same scenarios with the flag stripped (temp --root) do diff. A flagged last step is a HARNESS_ERROR.
const skipArgs = ["--only", "snap-skip", "--phlex-scenario", "snap-skip-slow"]
const skipped = run(skipArgs)
// (the duration-* class differs on purpose, so the checks look at the step names of the diffs, not at the exit code)
const atStep = (r, step) => (r.report?.diffs ?? []).filter((d) => d.step?.startsWith(step))
record("snapshot_false_skips_transient_diff", skipped.report && atStep(skipped, "1:wait").length === 0 && atStep(skipped, "2:wait").length > 0, { steps: [...new Set((skipped.report?.diffs ?? []).map((d) => d.step))] })
const harnessSpec = JSON.parse(fs.readFileSync(path.join(ROOT, LAYOUT.SCENARIOS_DIR, "_harness.json"), "utf8"))
const withRoot = (mutate, runArgs = skipArgs) => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "harness-selftest-"))
  fs.mkdirSync(path.join(dir, "scenarios"), { recursive: true })
  const copy = structuredClone(harnessSpec)
  copy.scenarios.forEach((sc) => mutate(sc))
  fs.writeFileSync(path.join(dir, "scenarios/_harness.json"), JSON.stringify(copy))
  try { return run([...runArgs, "--scenarios", path.join(dir, "scenarios"), "--react", recorded.vite.url, "--phlex", recorded.rails.url]) } finally { fs.rmSync(dir, { recursive: true, force: true }) }
}
const stripped = withRoot((sc) => (sc.steps ?? []).forEach((st) => { delete st.snapshot }))
record("snapshot_default_still_compares", stripped.report && atStep(stripped, "1:wait").some((d) => d.kind === "STYLE"), { steps: [...new Set((stripped.report?.diffs ?? []).map((d) => d.step))] })
const lastFlagged = withRoot((sc) => { if (sc.id === "snap-skip") sc.steps.at(-1).snapshot = false })
record("snapshot_false_last_step_rejected", lastFlagged.status === 1 && kinds(lastFlagged).includes("HARNESS_ERROR"), { exit: lastFlagged.status, kinds: kinds(lastFlagged) })

// `observe` (slot-less elements such as an svg icon): identical trees -> 0 diffs; a class difference on the Phlex side is a CLASS diff
// on the observed node; the same scenario without `observe` is EMPTY_RENDER (not vacuous); an invalid list is a HARNESS_ERROR.
const obsSame = run(["--only", "observe-svg"])
record("observe_identical_exit_0", obsSame.status === 0, { exit: obsSame.status, diffs: obsSame.report?.total_diffs })
const obsDiff = run(["--only", "observe-svg", "--phlex-scenario", "observe-svg-diff"])
record("observe_class_diff_detected", obsDiff.status === 1 && (obsDiff.report?.diffs ?? []).some((d) => d.kind === "CLASS" && d.at?.startsWith("observe:svg")), { exit: obsDiff.status, kinds: kinds(obsDiff) })
const obsOff = withRoot((sc) => { delete sc.observe }, ["--only", "observe-svg"])
record("observe_absent_is_empty_render", obsOff.status === 1 && kinds(obsOff).includes("EMPTY_RENDER"), { exit: obsOff.status, kinds: kinds(obsOff) })
const obsBad = withRoot((sc) => { if (sc.observe) sc.observe = [] }, ["--only", "observe-svg"])
record("observe_invalid_rejected", obsBad.status === 1 && kinds(obsBad).includes("HARNESS_ERROR"), { exit: obsBad.status, kinds: kinds(obsBad) })

// No-motion at load: content present at load with a starting-style transition must be at its final size (NO_MOTION is installed
// before page scripts, and reduced motion is never emulated so host-only media rules cannot differ). Source-level guard for the install.
const runnerSrc = fs.readFileSync(RUNNER, "utf8")
const noMotion = run(["--only", "no-motion-at-load"])
record("no_motion_installed_before_load", noMotion.status === 0 && /addInitScript\(installNoMotion/.test(runnerSrc) && !/reducedMotion: sc\.animations/.test(runnerSrc) && /reducedMotion: "no-preference"/.test(runnerSrc), { exit: noMotion.status, diffs: noMotion.report?.total_diffs })

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "harness-selftest-"))
fs.mkdirSync(path.join(tmp, "scenarios"), { recursive: true })
fs.writeFileSync(path.join(tmp, "scenarios/_harness.json"), JSON.stringify({ component: "_harness", scenarios: [{ id: "ghost-scenario", tree: { c: "_div" }, steps: [] }] }))
const ghost = run(["--scenarios", path.join(tmp, "scenarios"), "--react", recorded.vite.url, "--phlex", recorded.rails.url])
fs.rmSync(tmp, { recursive: true, force: true })
const want = ["HTTP_STATUS", "PARITY_ERROR", "EMPTY_RENDER"]
record("broken_pages_reported", ghost.status === 1 && want.every((k) => kinds(ghost).includes(k)), { exit: ghost.status, kinds: kinds(ghost) })

out.pass = Object.values(out.checks).every((c) => c.pass)
fs.mkdirSync(path.dirname(path.join(ROOT, LAYOUT.TMP_DIR, "_harness/selftest.json")), { recursive: true })
fs.writeFileSync(path.join(ROOT, LAYOUT.TMP_DIR, "_harness/selftest.json"), JSON.stringify(out, null, 2))
console.log(JSON.stringify(out, null, 2))
process.exit(out.pass ? 0 : 1)

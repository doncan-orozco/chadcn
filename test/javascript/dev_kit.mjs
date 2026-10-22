// Where the gem's dev kit lives (ruby-gem-conventions R1/R10). Playwright may come from the main checkout when this is a git
// worktree (worktrees carry no node_modules); the running Phlex server must come from THIS checkout, because it serves this
// checkout's gem. Environment: CHADCN_DEV_ROOT (relative paths are resolved from the working directory),
// CHADCN_PLAYWRIGHT (a directory with node_modules/playwright, CI), SHADCN_SERVERS_FILE (another servers.json).
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";

export const GEM_ROOT = path.resolve(import.meta.dirname, "../..");
const envPath = (name) => process.env[name] && path.resolve(process.env[name]);
const ownDevRoots = () => [envPath("CHADCN_DEV_ROOT"), path.join(GEM_ROOT, "dev")].filter(Boolean);

function mainCheckoutDevRoot() {
  try {
    const git = (...args) => execFileSync("git", ["-C", GEM_ROOT, ...args], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
    const mainRoot = path.dirname(git("rev-parse", "--path-format=absolute", "--git-common-dir"));
    return path.join(mainRoot, path.relative(git("rev-parse", "--show-toplevel"), GEM_ROOT), "dev");
  } catch {
    return null; // not a git checkout (e.g. the extracted gem)
  }
}

export function loadPlaywright() {
  const roots = [...ownDevRoots(), mainCheckoutDevRoot()].filter(Boolean);
  const catalogs = [...new Set([envPath("CHADCN_PLAYWRIGHT"), ...roots.map((root) => path.join(root, "react-shadcn-catalog"))].filter(Boolean))];
  const dir = catalogs.find((candidate) => fs.existsSync(path.join(candidate, "node_modules/playwright")));
  if (dir) return createRequire(path.join(dir, "package.json"))("playwright");
  throw new Error(`playwright not found in ${catalogs.join(", ")}: npm ci in gems/chadcn/dev/react-shadcn-catalog, or set CHADCN_PLAYWRIGHT / CHADCN_DEV_ROOT`);
}

export function serversFile() {
  const candidates = [envPath("SHADCN_SERVERS_FILE"), ...ownDevRoots().map((root) => path.join(root, "tmp/shadcn-port/servers.json"))].filter(Boolean);
  const found = candidates.find((file) => fs.existsSync(file));
  if (!found) throw new Error(`no servers.json in ${candidates.join(", ")}: start this checkout's dev servers (ruby .claude/scripts/shadcn/servers.rb start) or set PARITY_PHLEX_URL`);
  return found;
}

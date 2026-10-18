// One browser parity scenario against the clean app, adapted from dev/port/scenarios/dialog.json `open__via-trigger-click`:
// the same step (click the trigger by role) on the README's Dialog (trigger "Edit profile"), asserted by behavior (Radix DOM, focus
// moves in), then Escape closes it and focus returns to the trigger. The oracle compare stays in the dev kit's parity gates.
// Usage: node test/smoke/app/dialog_scenario.mjs http://127.0.0.1:PORT/demo
// Playwright comes from PHLEX_SHADCN_PLAYWRIGHT (a directory with node_modules/playwright), else the gem's dev kit
// (dev/react-shadcn-catalog/node_modules of this checkout, or of the main checkout: worktrees carry no node_modules).
import fs from "node:fs";
import path from "node:path";
import { execFileSync } from "node:child_process";
import { createRequire } from "node:module";

const GEM_ROOT = path.resolve(import.meta.dirname, "../../..");
const CATALOG = path.join("dev", "react-shadcn-catalog");
const url = process.argv[2];
if (!url) { console.error("usage: dialog_scenario.mjs URL"); process.exit(2); }

function git(...args) {
  return execFileSync("git", ["-C", GEM_ROOT, ...args], { encoding: "utf8" }).trim();
}

// The same gem directory inside the main checkout, when this one is a git worktree.
function mainCheckoutGemRoot() {
  try {
    const mainRoot = path.dirname(path.resolve(GEM_ROOT, git("rev-parse", "--git-common-dir")));
    return path.join(mainRoot, path.relative(git("rev-parse", "--show-toplevel"), GEM_ROOT));
  } catch {
    return null; // not a git checkout
  }
}

function loadPlaywright() {
  const dirs = [process.env.PHLEX_SHADCN_PLAYWRIGHT];
  for (const gemRoot of [GEM_ROOT, mainCheckoutGemRoot()]) {
    if (gemRoot) dirs.push(path.join(gemRoot, CATALOG));
  }
  for (const dir of dirs.filter(Boolean)) {
    if (fs.existsSync(path.join(dir, "node_modules/playwright"))) return createRequire(path.join(dir, "package.json"))("playwright");
  }
  try {
    return createRequire(import.meta.url)("playwright");
  } catch {
    throw new Error(`playwright not found; set PHLEX_SHADCN_PLAYWRIGHT or run npm install in ${path.join(GEM_ROOT, CATALOG)}`);
  }
}

const TIMEOUT = { connect: 15_000, state: 5_000 };
const TRIGGER = '[data-slot="dialog-trigger"]';

async function eventually(page, description, predicate, arg) {
  try {
    await page.waitForFunction(predicate, arg, { timeout: TIMEOUT.state });
  } catch {
    throw new Error(description);
  }
}

const { chromium } = loadPlaywright();
const browser = await chromium.launch();
const errors = [];
try {
  const page = await browser.newPage({ viewport: { width: 900, height: 700 } });
  page.on("pageerror", (error) => errors.push(`pageerror: ${error.message}`));
  page.on("console", (message) => {
    if (message.type() !== "error") return;
    errors.push(`console: ${message.text()} (${message.location().url})`);
  });
  page.on("response", (response) => { if (response.status() >= 400) errors.push(`${response.status()} ${response.url()}`); });
  page.on("requestfailed", (request) => errors.push(`requestfailed: ${request.url()} ${request.failure()?.errorText}`));

  await page.goto(url, { waitUntil: "load" });
  await page.locator('[data-controller~="shadcn--dialog"]').waitFor({ state: "attached" });
  // Rails loads controllers with dynamic imports after the page's load event; click only once shadcn--dialog is connected.
  await page.waitForFunction(() => {
    const element = document.querySelector('[data-controller~="shadcn--dialog"]');
    return window.Stimulus && element && window.Stimulus.getControllerForElementAndIdentifier(element, "shadcn--dialog");
  }, null, { timeout: TIMEOUT.connect });
  // The step targets the trigger by role, as the parity harness does; once the modal is open Radix hides everything else from
  // assistive technology (aria-hidden on the trigger's ancestors), so the later reads use the data-slot selector.
  const trigger = page.getByRole("button", { name: "Edit profile" });
  await trigger.waitFor();
  await eventually(page, "the trigger does not start with aria-expanded=false",
    (selector) => document.querySelector(selector)?.getAttribute("aria-expanded") === "false", TRIGGER);
  await eventually(page, "the trigger has no aria-haspopup=dialog",
    (selector) => document.querySelector(selector)?.getAttribute("aria-haspopup") === "dialog", TRIGGER);

  // open__via-trigger-click
  await trigger.click();
  const dialog = page.locator('[role="dialog"][data-state="open"]');
  await dialog.waitFor({ state: "visible", timeout: TIMEOUT.state });
  await dialog.getByText("Edit profile", { exact: true }).waitFor({ state: "visible", timeout: TIMEOUT.state })
    .catch(() => { throw new Error("the open dialog does not show its title"); });
  await eventually(page, "aria-expanded did not flip to true",
    (selector) => document.querySelector(selector)?.getAttribute("aria-expanded") === "true", TRIGGER);
  await eventually(page, "the page behind the modal is not aria-hidden (Radix hideOthers)",
    (selector) => Boolean(document.querySelector(selector)?.closest('[aria-hidden="true"]')), TRIGGER);
  await eventually(page, "focus did not move into the dialog",
    () => Boolean(document.querySelector('[role="dialog"][data-state="open"]')?.contains(document.activeElement)));

  // Escape closes and returns focus to the trigger (Radix FocusScope restores focus in a task after unmount)
  await page.keyboard.press("Escape");
  await page.locator('[role="dialog"]').waitFor({ state: "detached", timeout: TIMEOUT.state });
  await eventually(page, "aria-expanded did not return to false",
    (selector) => document.querySelector(selector)?.getAttribute("aria-expanded") === "false", TRIGGER);
  await eventually(page, "focus did not return to the trigger",
    (selector) => document.activeElement === document.querySelector(selector), TRIGGER);

  if (errors.length) throw new Error(`browser errors: ${errors.join("; ")}`);
  console.log("dialog scenario ok: open__via-trigger-click, Escape closes, focus returns");
} catch (error) {
  console.error(`dialog scenario failed: ${error.message}`);
  if (errors.length) console.error(`browser errors:\n  ${errors.join("\n  ")}`);
  process.exitCode = 1;
} finally {
  await browser.close();
}

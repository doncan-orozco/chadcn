// Unit-test harness for the shadcn primitives (app/javascript/shadcn/primitives/*.js). The real modules run in Chromium
// (Playwright); there is no jsdom, no Rails server, no vite and no servers.json. A page at http://primitives.test/ is served
// from memory through page.route: its importmap maps the `shadcn/primitives/<name>` specifiers (and the vendored
// @floating-ui packages) to the gem files, so a test does `await import("shadcn/primitives/presence")` inside page.evaluate.
// Playwright is resolved from the gem's dev kit (dev/react-shadcn-catalog/node_modules): CHADCN_PLAYWRIGHT (a directory with
// node_modules/playwright), CHADCN_DEV_ROOT (relative paths are resolved from the working directory), the dev kit of this
// checkout, else the one of the main checkout when this is a git worktree (worktrees do not carry node_modules).
import fs from "node:fs";
import path from "node:path";
import test, { after } from "node:test";
import { GEM_ROOT, loadPlaywright } from "./dev_kit.mjs";
import assert from "node:assert/strict";

export { assert };

const PRIMITIVES_DIR = path.join(GEM_ROOT, "app/javascript/shadcn/primitives");
const VENDOR_DIR = path.join(GEM_ROOT, "vendor/javascript");
const ORIGIN = "http://primitives.test";

const { chromium } = loadPlaywright();

const NO_MOTION = "*,*::before,*::after{animation:none!important;transition:none!important}";

const importMap = () => {
  const imports = {
    "@floating-ui/dom": "/vendor/@floating-ui--dom.js",
    "@floating-ui/core": "/vendor/@floating-ui--core.js",
    "@floating-ui/utils": "/vendor/@floating-ui--utils.js",
    "@floating-ui/utils/dom": "/vendor/@floating-ui--utils--dom.js",
  };
  for (const file of fs.readdirSync(PRIMITIVES_DIR)) {
    if (file.endsWith(".js")) imports[`shadcn/primitives/${file.slice(0, -3)}`] = `/primitives/${file}`;
  }
  return { imports };
};

const indexHtml = (css) => `<!doctype html><html><head><meta charset="utf-8">
<script type="importmap">${JSON.stringify(importMap())}</script>
<style>${css}</style></head><body></body></html>`;

function serve(css) {
  return async (route) => {
    const { pathname } = new URL(route.request().url());
    const file = pathname.startsWith("/primitives/") ? path.join(PRIMITIVES_DIR, path.basename(pathname))
      : pathname.startsWith("/vendor/") ? path.join(VENDOR_DIR, path.basename(pathname)) : null;
    if (pathname === "/index.html") return route.fulfill({ contentType: "text/html", body: indexHtml(css) });
    if (file && fs.existsSync(file)) return route.fulfill({ contentType: "text/javascript", body: fs.readFileSync(file, "utf8") });
    return route.fulfill({ status: 404, body: "not found" });
  };
}

// Playwright launches Chromium with --hide-scrollbars; `scrollbars: true` uses a second browser that keeps classic scrollbars.
const browsers = {};
const browser = (scrollbars = false) => (browsers[scrollbars] ??= chromium.launch(scrollbars ? { ignoreDefaultArgs: ["--hide-scrollbars"] } : {}));
after(async () => { for (const promise of Object.values(browsers)) await (await promise)?.close(); });

// A fresh page per test (module state such as layer stacks starts clean). `motion: true` keeps CSS animations/transitions
// (presence tests define their own); `css` adds page styles; `html` seeds <body>.
export async function openPage({ motion = false, css = "", html = "", scrollbars = false, viewport = { width: 800, height: 600 } } = {}) {
  const context = await (await browser(scrollbars)).newContext({ viewport });
  const page = await context.newPage();
  page.jsErrors = [];
  page.on("pageerror", (error) => page.jsErrors.push(String(error)));
  await page.route(`${ORIGIN}/**`, serve((motion ? "" : NO_MOTION) + css));
  await page.goto(`${ORIGIN}/index.html`);
  if (html) await page.evaluate((markup) => { document.body.innerHTML = markup }, html);
  return page;
}

// node:test wrapper: `primitiveTest(name, async (page) => {...}, { html, css, motion })`. Fails on uncaught page errors.
export function primitiveTest(name, fn, options = {}) {
  const run = options.todo ? test.todo : test;
  return run(name, async () => {
    const page = await openPage(options);
    try {
      await fn(page);
      if (page.jsErrors.length) throw new Error(`page errors: ${page.jsErrors.join("; ")}`);
    } finally {
      await page.context().close().catch(() => {});
    }
  });
}

// Two animation frames: layout, observers and rAF callbacks have run.
export const frames = (page) => page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));

// One macrotask: `setTimeout(fn, 0)` work scheduled by a primitive has run.
export const tick = (page) => page.evaluate(() => new Promise((resolve) => setTimeout(resolve, 0)));

// Replaces window.setTimeout/clearTimeout with a manual clock so timer-driven primitives are deterministic:
// `await page.evaluate(() => window.__clock.advance(300))` fires every timer due within 300 ms, in order. Call it right after
// openPage (before importing the primitive). `tick` and other code that waits on real timers must not be used afterwards.
export async function useFakeTimers(page) {
  await page.evaluate(() => {
    let now = 0;
    let lastId = 0;
    const timers = new Map();
    window.setTimeout = (fn, ms = 0) => { timers.set(++lastId, { fn, at: now + ms }); return lastId };
    window.clearTimeout = (id) => { timers.delete(id) };
    window.__clock = {
      pending: () => timers.size,
      advance(ms) {
        const end = now + ms;
        for (;;) {
          const due = [...timers.entries()].filter(([, timer]) => timer.at <= end).sort(([a, x], [b, y]) => x.at - y.at || a - b)[0];
          if (!due) break;
          timers.delete(due[0]);
          now = Math.max(now, due[1].at);
          due[1].fn();
        }
        now = end;
      },
    };
  });
}

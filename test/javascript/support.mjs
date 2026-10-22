// Browser-driven tests for the chadcn Stimulus controllers: behavior that the parity runner cannot express (touch input,
// cancelable public events, positioner options). They load the real Phlex parity page (real importmap, real controllers)
// and use the Playwright of react-shadcn-catalog. Run with `bin/rails test:javascript` (starts the dev servers).
import fs from "node:fs";
import assert from "node:assert/strict";
import { loadPlaywright, serversFile } from "./dev_kit.mjs";

// Dev-kit coupling (ruby-gem-conventions R1/R10): see dev_kit.mjs for where Playwright and the running Phlex server are looked up.
const { chromium } = loadPlaywright();

export const PHLEX = process.env.PARITY_PHLEX_URL || JSON.parse(fs.readFileSync(serversFile(), "utf8")).rails.url;


const NO_MOTION = "*,*::before,*::after{animation:none!important;transition:none!important}";

export async function launch() {
  return chromium.launch();
}

// A fresh page on a parity scenario of the Phlex port, controllers connected and settled.
export async function openScenario(browser, component, scenario, { touch = false } = {}) {
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 }, hasTouch: touch });
  await context.addInitScript((css) => {
    document.addEventListener("DOMContentLoaded", () => {
      const style = document.createElement("style");
      style.textContent = css;
      document.head.append(style);
    });
  }, NO_MOTION);
  const page = await context.newPage();
  const errors = [];
  page.on("pageerror", (error) => errors.push(String(error)));
  // networkidle: the importmap modules (Stimulus, controllers) load after the load event, like parity_run.mjs.
  await page.goto(`${PHLEX}/design-system/parity/${component}/${scenario}`, { waitUntil: "networkidle" });
  await page.evaluate(() => document.fonts?.ready);
  await settle(page);
  page.jsErrors = errors;
  return page;
}

export async function settle(page) {
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(() => setTimeout(resolve, 0)))));
}

// Rewrites the options JSON of the content <template> and reconnects the controller so it reads them again.
export async function reconnectWithOptions(page, { template, controller, options = {}, values = {} }) {
  await page.evaluate(({ template, controller, options, values }) => {
    const tpl = document.querySelector(template);
    tpl.dataset.options = JSON.stringify({ ...JSON.parse(tpl.dataset.options || "{}"), ...options });
    const host = document.querySelector(`[data-controller~="${controller}"]`);
    for (const [name, value] of Object.entries(values)) host.setAttribute(`data-${controller}-${name}-value`, value);
    const original = host.getAttribute("data-controller");
    host.setAttribute("data-controller", original.split(/\s+/).filter((c) => c !== controller).join(" "));
    return new Promise((resolve) => requestAnimationFrame(() => {
      host.setAttribute("data-controller", original);
      resolve();
    }));
  }, { template, controller, options, values });
  await settle(page);
}

// Collects the public events (`chadcn--x:name`) a controller dispatches, optionally preventing some of them.
export async function recordEvents(page, prefix, { prevent = [] } = {}) {
  await page.evaluate(({ prefix, prevent }) => {
    window.__events = [];
    document.addEventListener("DOMContentLoaded", () => {}, { once: true });
    const names = ["open-change", "escape-key-down", "pointer-down-outside", "focus-outside", "interact-outside", "open-auto-focus", "close-auto-focus"];
    for (const name of names) {
      document.addEventListener(`${prefix}:${name}`, (event) => {
        window.__events.push({ name, open: event.detail?.open, cancelable: event.cancelable });
        if (prevent.includes(name)) event.preventDefault();
      });
    }
  }, { prefix, prevent });
}

export const events = (page) => page.evaluate(() => window.__events.map((e) => e.name));
export const eventLog = (page) => page.evaluate(() => window.__events);
export const contentCount = (page, selector) => page.locator(selector).count();

export { assert };

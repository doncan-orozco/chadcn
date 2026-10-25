// Browser-driven tests for the chadcn Stimulus controllers: behavior that the parity runner cannot express (touch input,
// cancelable public events, positioner options). They load the real Phlex parity page (real importmap, real controllers)
// and use the Playwright of react-shadcn-catalog. Run with `bin/test-js` (starts the dev servers).
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

// A fresh page at `path` of the Phlex server, controllers connected and settled.
export async function openPath(browser, path, { touch = false } = {}) {
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
  await page.goto(`${PHLEX}${path}`, { waitUntil: "networkidle" });
  await page.evaluate(() => document.fonts?.ready);
  await settle(page);
  page.jsErrors = errors;
  return page;
}

// A fresh page on a parity scenario of the Phlex port.
export const openScenario = (browser, component, scenario, options) => openPath(browser, `/design-system/parity/${component}/${scenario}`, options);

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

// Stimulus reports an error raised in connect() with console.error, not as a page error. The array fills as the page logs.
export const consoleErrors = (page) => {
  const errors = [];
  page.on("console", (message) => { if (message.type() === "error") errors.push(message.text()); });
  return errors;
};

// The selector of the element a Stimulus controller is connected to.
export const host = (controller) => `[data-controller~="${controller}"]`;

// Removes the controller host and puts it back in the same place: Stimulus disconnects on the mutation-observer microtask and
// connects a new controller on reinsert. Waits on ticks, never on the clock (testing R9). `anchor` picks the reinsert position.
export const reconnect = (page, controller, { anchor = "next" } = {}) => page.evaluate(async ({ selector, anchor }) => {
  const tick = () => new Promise((resolve) => setTimeout(resolve))
  const control = document.querySelector(selector)
  const parent = control.parentNode
  const input = control.nextElementSibling
  const next = anchor === "bubble-input" ? (input?.nextSibling ?? null) : control.nextSibling
  control.remove()
  await tick()
  parent.insertBefore(control, anchor === "bubble-input" && input?.isConnected ? input : next)
  await tick()
}, { selector: host(controller), anchor })

export const events = (page) => page.evaluate(() => window.__events.map((e) => e.name));
export const eventLog = (page) => page.evaluate(() => window.__events);
export const contentCount = (page, selector) => page.locator(selector).count();

export { assert };

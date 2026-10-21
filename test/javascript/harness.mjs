// Tiny node:test wrapper: one browser per file, one fresh page per scenario, `open` fixture helpers.
import test, { after } from "node:test";
import { launch, openScenario } from "./support.mjs";

let browserPromise;
const browser = () => (browserPromise ??= launchBrowser());

// SHADCN_TEST_TIMER_DELAY_MS=<ms> emulates a starved runner: every zero-delay setTimeout of the page under test fires that late
// (input is still delivered at once), which is how a press that lands before a controller's deferred listener is armed is reproduced.
// Scope: pages opened through browserTest only (primitive tests build their own contexts).
const RAW_TIMER_DELAY = process.env.SHADCN_TEST_TIMER_DELAY_MS;
const TIMER_DELAY_MS = RAW_TIMER_DELAY === undefined || RAW_TIMER_DELAY === "" ? 0 : Number(RAW_TIMER_DELAY);
if (!Number.isFinite(TIMER_DELAY_MS) || TIMER_DELAY_MS < 0) throw new Error(`SHADCN_TEST_TIMER_DELAY_MS must be a non-negative number, got ${JSON.stringify(RAW_TIMER_DELAY)}`);

async function launchBrowser() {
  const instance = await launch();
  if (!TIMER_DELAY_MS) return instance;
  const newContext = instance.newContext.bind(instance);
  instance.newContext = async (...args) => {
    const context = await newContext(...args);
    await context.addInitScript((ms) => {
      const native = window.setTimeout.bind(window);
      window.setTimeout = (fn, wait, ...rest) => native(fn, wait ? wait : ms, ...rest);
    }, TIMER_DELAY_MS);
    return context;
  };
  return instance;
}
after(async () => { await (await browserPromise)?.close(); });

export function browserTest(name, fn, { touch = false } = {}) {
  return test(name, async () => {
    const pages = [];
    const open = async (scenario, component = browserTest.component) => {
      const page = await openScenario(await browser(), component, scenario, { touch });
      pages.push(page);
      return page;
    };
    try {
      await fn({ open });
      for (const page of pages) if (page.jsErrors.length) throw new Error(`page errors: ${page.jsErrors.join("; ")}`);
    } finally {
      await Promise.all(pages.map((page) => page.context().close().catch(() => {})));
    }
  });
}

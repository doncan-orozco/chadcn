// Tiny node:test wrapper: one browser per file, one fresh page per scenario, `open` fixture helpers.
import test, { after } from "node:test";
import { launch, openScenario } from "./support.mjs";

let browserPromise;
const browser = () => (browserPromise ??= launch());
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

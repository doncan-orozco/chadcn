import { browserTest } from "./harness.mjs";
import { assert, settle } from "./support.mjs";

// The theme controller needs no Phlex markup: any parity page loads the importmap and registers every controller, so each test
// mounts a host element on it (Stimulus connects it through its MutationObserver) after preparing storage and the color scheme.
browserTest.component = "button";

const KEY = "shadcn-theme";
const mount = async (page, attributes = "") => {
  await page.evaluate((attrs) => {
    document.body.insertAdjacentHTML("beforeend", `<div id="theme-host" data-controller="chadcn--theme" ${attrs}></div>`);
  }, attributes);
  await page.waitForFunction(() => window.Stimulus?.getControllerForElementAndIdentifier(document.querySelector("#theme-host"), "chadcn--theme"));
  await settle(page);
};
const html = (page) => page.evaluate(() => ({ dark: document.documentElement.classList.contains("dark"), theme: document.documentElement.dataset.theme }));
const act = (page, action) => page.evaluate((name) => window.Stimulus.getControllerForElementAndIdentifier(document.querySelector("#theme-host"), "chadcn--theme")[name](), action);

browserTest("theme: the default storage key is neutral and a stored choice is applied on connect", async ({ open }) => {
  const page = await open("defaults");
  await page.emulateMedia({ colorScheme: "light" });
  await page.evaluate((key) => { localStorage.clear(); localStorage.setItem(key, "dark"); localStorage.setItem("papyro-theme", "dark"); }, KEY);
  await mount(page);
  assert.deepEqual(await html(page), { dark: true, theme: "dark" });
  await act(page, "setLight");
  assert.equal(await page.evaluate((key) => localStorage.getItem(key), KEY), "light");
  assert.equal(await page.evaluate(() => localStorage.getItem("papyro-theme")), "dark", "the old project-specific key is never written");
  assert.deepEqual(await html(page), { dark: false, theme: "light" });
  await act(page, "setSystem");
  assert.equal(await page.evaluate((key) => localStorage.getItem(key), KEY), null, "system removes the stored choice");
});

browserTest("theme: data-chadcn--theme-storage-key-value overrides the key", async ({ open }) => {
  const page = await open("defaults");
  await page.emulateMedia({ colorScheme: "light" });
  await page.evaluate(() => { localStorage.clear(); localStorage.setItem("my-app-theme", "dark"); localStorage.setItem("shadcn-theme", "sentinel"); });
  await mount(page, 'data-chadcn--theme-storage-key-value="my-app-theme"');
  assert.deepEqual(await html(page), { dark: true, theme: "dark" }, "reads the custom key, not the default one");
  await act(page, "setLight");
  await act(page, "toggle");
  assert.deepEqual(await page.evaluate(() => [localStorage.getItem("my-app-theme"), localStorage.getItem("shadcn-theme")]), ["dark", "sentinel"], "only the configured key is written");
});

browserTest("theme: an unknown stored value falls back to the system preference", async ({ open }) => {
  const page = await open("defaults");
  await page.emulateMedia({ colorScheme: "dark" });
  await page.evaluate((key) => localStorage.setItem(key, "sepia"), KEY);
  await mount(page);
  assert.deepEqual(await html(page), { dark: true, theme: "system" });
});

browserTest("theme: storage that throws still follows the system preference and changes apply to the page", async ({ open }) => {
  const page = await open("defaults");
  await page.emulateMedia({ colorScheme: "dark" });
  await page.evaluate(() => {
    const fail = () => { throw new DOMException("blocked", "SecurityError"); };
    for (const method of ["getItem", "setItem", "removeItem"]) Storage.prototype[method] = fail;
  });
  await mount(page);
  assert.deepEqual(await html(page), { dark: true, theme: "system" }, "connect did not throw: the class follows the system preference");
  await act(page, "setLight");
  assert.deepEqual(await html(page), { dark: false, theme: "light" }, "a choice still applies to this page");
  await page.emulateMedia({ colorScheme: "light" });
  await act(page, "setSystem");
  assert.deepEqual(await html(page), { dark: false, theme: "system" });
});

browserTest("theme: the system preference is mirrored live while the choice is system", async ({ open }) => {
  const page = await open("defaults");
  await page.emulateMedia({ colorScheme: "light" });
  await mount(page);
  assert.equal((await html(page)).dark, false);
  await page.emulateMedia({ colorScheme: "dark" });
  await page.waitForFunction(() => document.documentElement.classList.contains("dark"));
});

browserTest("theme: toggle cycles system, light, dark and dispatches chadcn--theme:changed with the choice", async ({ open }) => {
  const page = await open("defaults");
  await page.emulateMedia({ colorScheme: "light" });
  await mount(page);
  await page.evaluate(() => { window.__themes = []; document.addEventListener("chadcn--theme:changed", (event) => window.__themes.push(event.detail.theme)); });
  for (let i = 0; i < 3; i++) await act(page, "toggle");
  assert.deepEqual(await page.evaluate(() => window.__themes), ["light", "dark", "system"]);
});

browserTest("theme: an empty storage key value falls back to the default key", async ({ open }) => {
  const page = await open("defaults");
  await page.emulateMedia({ colorScheme: "light" });
  await mount(page, 'data-chadcn--theme-storage-key-value=""');
  await act(page, "setDark");
  assert.equal(await page.evaluate((key) => localStorage.getItem(key), KEY), "dark");
  assert.equal(await page.evaluate(() => localStorage.getItem("")), null);
});

browserTest("theme: after disconnect the system preference is no longer followed", async ({ open }) => {
  const page = await open("defaults");
  await page.emulateMedia({ colorScheme: "light" });
  await mount(page);
  await page.evaluate(() => document.querySelector("#theme-host").remove());
  await settle(page);
  await page.emulateMedia({ colorScheme: "dark" });
  await settle(page);
  assert.equal((await html(page)).dark, false, "the media listener was released");
});

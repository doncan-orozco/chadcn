import { browserTest } from "./harness.mjs";
import { assert, settle } from "./support.mjs";

// The theme controller needs no Phlex markup: any parity page loads the importmap and registers every controller, so each test
// mounts a host element on it (Stimulus connects it through its MutationObserver) after preparing storage and the color scheme.
browserTest.component = "button";

const KEY = "shadcn-theme";
const mount = async (page, attributes = "", id = "theme-host") => {
  await page.evaluate(({ attrs, id }) => {
    document.body.insertAdjacentHTML("beforeend", `<div id="${id}" data-controller="chadcn--theme" ${attrs}></div>`);
  }, { attrs: attributes, id });
  await page.waitForFunction((id) => window.Stimulus?.getControllerForElementAndIdentifier(document.querySelector(`#${id}`), "chadcn--theme"), id);
  await settle(page);
};
const html = (page) => page.evaluate(() => ({ dark: document.documentElement.classList.contains("dark"), theme: document.documentElement.dataset.theme }));
const act = (page, action, id = "theme-host") => page.evaluate(({ name, id }) => window.Stimulus.getControllerForElementAndIdentifier(document.querySelector(`#${id}`), "chadcn--theme")[name](), { name: action, id });
const currentValue = (page, id = "theme-host") => page.evaluate((id) => window.Stimulus.getControllerForElementAndIdentifier(document.querySelector(`#${id}`), "chadcn--theme").currentValue, id);
const stored = (page, key = KEY) => page.evaluate((key) => localStorage.getItem(key), key);
const record = (page) => page.evaluate(() => { window.__themes = []; document.addEventListener("chadcn--theme:changed", (event) => window.__themes.push(event.detail.theme)); });
const recorded = (page) => page.evaluate(() => window.__themes);

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

browserTest("theme: instances with the same storage key stay in sync and a stale instance never overrides the stored choice", async ({ open }) => {
  const page = await open("defaults");
  await page.emulateMedia({ colorScheme: "light" });
  await page.evaluate(() => localStorage.clear());
  await mount(page);
  await mount(page, "", "theme-host-portaled");
  await record(page);
  await act(page, "setLight", "theme-host-portaled");
  assert.equal(await stored(page), "light");
  assert.deepEqual(await html(page), { dark: false, theme: "light" });
  assert.deepEqual(await recorded(page), ["light"], "one dispatch for one choice: adopting it in the other instance does not dispatch again");
  assert.equal(await currentValue(page), "light", "the instance that did not handle the click adopted the choice");
  await page.emulateMedia({ colorScheme: "dark" });
  await settle(page);
  assert.deepEqual(await html(page), { dark: false, theme: "light" }, "after the OS scheme change a stale instance does not re-apply system over the stored choice");
  assert.equal(await stored(page), "light");
  await act(page, "setSystem");
  assert.equal(await stored(page), null, "system removes the stored choice");
  assert.deepEqual(await html(page), { dark: true, theme: "system" }, "system follows the dark OS scheme");
  assert.equal(await currentValue(page, "theme-host-portaled"), "system", "the other instance adopted system");
  assert.deepEqual(await recorded(page), ["light", "system"]);
});

browserTest("theme: an instance with another storage key ignores a choice made under a different key", async ({ open }) => {
  const page = await open("defaults");
  await page.emulateMedia({ colorScheme: "light" });
  await page.evaluate(() => localStorage.clear());
  await mount(page);
  await mount(page, 'data-chadcn--theme-storage-key-value="my-app-theme"', "theme-host-other");
  await act(page, "setDark");
  assert.equal(await stored(page), "dark", "control: the choice was persisted under the default key");
  assert.equal(await currentValue(page, "theme-host-other"), "system", "the instance with another key kept its own value");
  assert.equal(await stored(page, "my-app-theme"), null);
  assert.deepEqual(await html(page), { dark: true, theme: "dark" }, "the page carries the last writer's choice");
});

browserTest("theme: a storage event from another page of the same origin re-syncs the instance", async ({ open }) => {
  const page = await open("defaults");
  await page.emulateMedia({ colorScheme: "light" });
  await page.evaluate(() => localStorage.clear());
  await mount(page);
  await record(page);
  assert.deepEqual(await html(page), { dark: false, theme: "system" }, "control: the instance starts on system");
  const other = await page.context().newPage();
  try {
    await other.goto(page.url(), { waitUntil: "load" });
    await other.evaluate((key) => localStorage.setItem(key, "dark"), KEY);
    await page.waitForFunction(() => document.documentElement.classList.contains("dark") && document.documentElement.dataset.theme === "dark");
    assert.equal(await currentValue(page), "dark", "the instance re-read the key changed elsewhere");
    assert.deepEqual(await recorded(page), [], "syncing never dispatches");
    await other.evaluate((key) => localStorage.removeItem(key), KEY);
    await page.waitForFunction(() => document.documentElement.dataset.theme === "system");
    assert.deepEqual(await html(page), { dark: false, theme: "system" }, "a cleared key falls back to system, light under the light scheme");
    assert.deepEqual(await recorded(page), []);
  } finally {
    await other.close();
  }
});

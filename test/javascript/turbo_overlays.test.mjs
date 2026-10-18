import { browserTest } from "./harness.mjs";
import { assert, settle } from "./support.mjs";

// Turbo page cache: the snapshot is taken after turbo:before-cache, so the overlays must be gone by then (radix-stimulus
// R10). The restore is simulated by re-inserting the controller host as it is in that snapshot, which connects a new one.
const CASES = [
  { component: "dialog", controller: "shadcn--dialog", scenario: "closed__rest", content: "[data-slot=dialog-content]", overlay: "[data-slot=dialog-overlay]" },
  { component: "sheet", controller: "shadcn--sheet", scenario: "closed__rest", content: "[data-slot=sheet-content]", overlay: "[data-slot=sheet-overlay]" },
  { component: "alert-dialog", controller: "shadcn--alert-dialog", scenario: "closed__rest", content: "[data-slot=alert-dialog-content]", overlay: "[data-slot=alert-dialog-overlay]" }
];

const trigger = (c) => `[data-controller~="${c.controller}"] [data-shadcn--dialog-part=trigger], [data-controller~="${c.controller}"] [data-slot$=-trigger]`;

// What Turbo's snapshot would contain one timer tick after the event (the controller restores a staying page after that).
const snapshotAfterBeforeCache = (page, c) => page.evaluate(async ({ controller, content, overlay }) => {
  document.dispatchEvent(new Event("turbo:before-cache"))
  await new Promise((resolve) => setTimeout(resolve))
  const host = document.querySelector(`[data-controller~="${controller}"]`)
  return {
    contents: document.querySelectorAll(content).length,
    overlays: document.querySelectorAll(overlay).length,
    scrollLocked: document.body.hasAttribute("data-scroll-locked"),
    pointerEvents: document.body.style.pointerEvents,
    hidden: document.querySelectorAll("[aria-hidden=true]").length,
    open: host.getAttribute(`data-${controller}-open-value`),
    expanded: [...host.querySelectorAll("[aria-expanded]")].map((el) => el.getAttribute("aria-expanded")),
    html: host.outerHTML
  }
}, c)

const hiddenCount = (page) => page.evaluate(() => document.querySelectorAll("[aria-hidden=true]").length)
const scrollLocked = (page) => page.evaluate(() => document.body.hasAttribute("data-scroll-locked"))

for (const c of CASES) {
  browserTest(`${c.component}: the Turbo snapshot has no overlay, scroll lock or aria-hidden and the dialog is closed`, async ({ open }) => {
    const page = await open(c.scenario, c.component)
    const hiddenBefore = await hiddenCount(page)
    await page.locator(trigger(c)).first().click()
    await page.waitForSelector(c.content)
    await settle(page)
    assert.equal(await scrollLocked(page), true, "precondition: body is scroll locked")
    assert.equal(await page.evaluate(() => document.body.style.pointerEvents), "none", "precondition: outside pointer events are disabled")
    assert.ok((await hiddenCount(page)) > hiddenBefore, "precondition: siblings are aria-hidden")

    const snapshot = await snapshotAfterBeforeCache(page, c)

    assert.equal(snapshot.contents, 0)
    assert.equal(snapshot.overlays, 0)
    assert.equal(snapshot.scrollLocked, false)
    assert.notEqual(snapshot.pointerEvents, "none")
    assert.equal(snapshot.hidden, hiddenBefore)
    assert.notEqual(snapshot.open, "true")
    assert.ok(snapshot.expanded.length > 0)
    assert.ok(snapshot.expanded.every((value) => value === "false"))
  })

  browserTest(`${c.component}: the restored snapshot has no overlay and can be opened again`, async ({ open }) => {
    const page = await open(c.scenario, c.component)
    assert.equal(await scrollLocked(page), false, "precondition: body starts unlocked")
    await page.locator(trigger(c)).first().click()
    await page.waitForSelector(c.content)
    await settle(page)
    const { html } = await snapshotAfterBeforeCache(page, c)
    // Restore: the snapshot's host replaces the live one (which disconnects), so a new controller connects to it.
    await page.evaluate(({ controller, html }) => {
      const host = document.querySelector(`[data-controller~="${controller}"]`)
      host.insertAdjacentHTML("afterend", html)
      host.remove()
    }, { controller: c.controller, html })
    await settle(page)
    assert.equal(await page.locator(c.content).count(), 0)
    assert.equal(await page.locator(c.overlay).count(), 0)
    await page.locator(trigger(c)).first().click()
    await page.waitForSelector(c.content)
    assert.equal(await page.locator(c.content).count(), 1)
    assert.equal(await page.locator(c.overlay).count(), 1)
    assert.equal(await scrollLocked(page), true)
  })

  browserTest(`${c.component}: before-cache without a navigation (Turbo keeps the page, e.g. a #hash link) re-opens the dialog after the snapshot`, async ({ open }) => {
    const page = await open(c.scenario, c.component)
    await page.locator(trigger(c)).first().click()
    await page.waitForSelector(c.content)
    await snapshotAfterBeforeCache(page, c)
    await page.waitForSelector(c.content)
    await settle(page)
    assert.equal(await page.locator(c.content).count(), 1)
    assert.equal(await page.locator(c.overlay).count(), 1)
    assert.equal(await scrollLocked(page), true)
    assert.equal(await page.locator(trigger(c)).first().getAttribute("aria-expanded"), "true")
  })

  browserTest(`${c.component}: a reconnect inside the restore window does not re-open the dialog`, async ({ open }) => {
    const page = await open(c.scenario, c.component)
    await page.locator(trigger(c)).first().click()
    await page.waitForSelector(c.content)
    await settle(page)
    await page.evaluate(async (controller) => {
      const host = document.querySelector(`[data-controller~="${controller}"]`)
      const parent = host.parentNode
      const next = host.nextSibling
      document.dispatchEvent(new Event("turbo:before-cache"))
      host.remove()
      await new Promise((resolve) => setTimeout(resolve)) // Stimulus disconnects on the mutation observer microtask
      parent.insertBefore(host, next)
      for (let tick = 0; tick < 3; tick++) await new Promise((resolve) => setTimeout(resolve))
    }, c.controller)
    await settle(page)
    assert.equal(await page.locator(c.content).count(), 0)
    assert.equal(await page.locator(c.overlay).count(), 0)
    assert.equal(await scrollLocked(page), false)
  })
}

// Turbo keeps the page for a #hash visit: a closed dialog must not lose its forceMount parts (nothing mounts them again).
// The Ruby Dialog does not emit forceMount (the api__content-force-mount scenario renders none), so it is set on the template.
browserTest("dialog: a closed dialog keeps its forceMount parts through before-cache on a staying page", async ({ open }) => {
  const page = await open("closed__rest", "dialog");
  await page.evaluate(() => new Promise((resolve) => {
    const host = document.querySelector('[data-controller~="shadcn--dialog"]');
    host.querySelectorAll("template[data-shadcn--dialog-template]").forEach((t) => t.setAttribute("data-shadcn--dialog-options", JSON.stringify({ forceMount: true })));
    host.setAttribute("data-controller", "");
    requestAnimationFrame(() => { host.setAttribute("data-controller", "shadcn--dialog"); resolve(); });
  }));
  await settle(page);
  const mounted = () => page.locator("[data-slot=dialog-content], [data-slot=dialog-overlay]").count();
  const before = await mounted();
  const lockedBefore = await scrollLocked(page);
  assert.ok(before >= 1, "precondition: a forceMount part is mounted while closed");
  await page.evaluate(async () => {
    document.dispatchEvent(new Event("turbo:before-cache"));
    for (let tick = 0; tick < 3; tick++) await new Promise((resolve) => setTimeout(resolve));
  });
  await settle(page);
  assert.equal(await mounted(), before);
  assert.equal(await scrollLocked(page), lockedBefore);
});

// The destructive Action comes before Cancel in the DOM, so only the redirect to Cancel (not the first tabbable) passes.
browserTest("alert-dialog: open on first paint focuses the Cancel button, not the first tabbable", async ({ open }) => {
  const page = await open("closed__rest", "alert-dialog");
  await page.evaluate(() => {
    const host = document.querySelector('[data-controller~="shadcn--alert-dialog"]');
    const restored = host.cloneNode(true);
    const content = restored.querySelector("template[data-shadcn--dialog-template]").content;
    const cancel = content.querySelector("[data-shadcn--alert-dialog-part=cancel]");
    const action = content.querySelector("[data-slot=alert-dialog-action]");
    cancel.before(action);
    restored.setAttribute("data-shadcn--alert-dialog-open-value", "true");
    host.replaceWith(restored);
  });
  await page.waitForSelector("[data-slot=alert-dialog-content]");
  await settle(page);
  const active = await page.evaluate(() => document.activeElement?.getAttribute("data-shadcn--alert-dialog-part"));
  assert.equal(active, "cancel");
});

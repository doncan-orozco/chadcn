import { browserTest } from "./harness.mjs";
import { assert, settle } from "./support.mjs";

// Turbo page cache: the snapshot is taken after turbo:before-cache, so the overlays must be gone by then (radix-stimulus
// R10). The restore is simulated by re-inserting the controller host as it is in that snapshot, which connects a new one.
const CASES = [
  { component: "dialog", controller: "chadcn--dialog", scenario: "closed__rest", content: "[data-slot=dialog-content]", overlay: "[data-slot=dialog-overlay]" },
  { component: "sheet", controller: "chadcn--sheet", scenario: "closed__rest", content: "[data-slot=sheet-content]", overlay: "[data-slot=sheet-overlay]" },
  { component: "alert-dialog", controller: "chadcn--alert-dialog", scenario: "closed__rest", content: "[data-slot=alert-dialog-content]", overlay: "[data-slot=alert-dialog-overlay]" }
];

const trigger = (c) => `[data-controller~="${c.controller}"] [data-chadcn--dialog-part=trigger], [data-controller~="${c.controller}"] [data-slot$=-trigger]`;

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

  browserTest(`${c.component}: a second before-cache inside the restore window still re-opens the dialog after the snapshot`, async ({ open }) => {
    const page = await open(c.scenario, c.component)
    await page.locator(trigger(c)).first().click()
    await page.waitForSelector(c.content)
    await settle(page)
    const atSecondSnapshot = await page.evaluate(async (content) => {
      const nextTick = () => new Promise((resolve) => setTimeout(resolve))
      document.dispatchEvent(new Event("turbo:before-cache"))
      await nextTick() // the first snapshot; the restore is one tick away
      document.dispatchEvent(new Event("turbo:before-cache")) // the dialog is closed now: only the carried state re-opens it
      await nextTick()
      return document.querySelectorAll(content).length
    }, c.content)
    assert.equal(atSecondSnapshot, 0, "the second snapshot holds no dialog")
    await page.waitForSelector(c.content, { timeout: 2000 })
    await settle(page)
    assert.equal(await page.locator(c.content).count(), 1)
    assert.equal(await page.locator(c.overlay).count(), 1)
    assert.equal(await scrollLocked(page), true)
    assert.equal(await page.locator(trigger(c)).first().getAttribute("aria-expanded"), "true")
  })

  // The negative twin of the case above: the carry is the open state, not the second event (a teardown carrying `pending` alone
  // opens a closed dialog here).
  browserTest(`${c.component}: a closed dialog stays closed through a second before-cache inside the restore window`, async ({ open }) => {
    const page = await open(c.scenario, c.component)
    await settle(page)
    assert.equal(await page.locator(c.content).count(), 0, "precondition: the dialog is closed")
    const mounted = await page.evaluate(async (content) => {
      const nextTick = () => new Promise((resolve) => setTimeout(resolve))
      const count = () => document.querySelectorAll(content).length
      document.dispatchEvent(new Event("turbo:before-cache"))
      await nextTick() // the first snapshot; the restore is one tick away
      document.dispatchEvent(new Event("turbo:before-cache"))
      await nextTick() // the second snapshot
      const atSecondSnapshot = count()
      const { SNAPSHOT_TICKS } = await import("chadcn/primitives/turbo_cache")
      for (let tick = 0; tick <= SNAPSHOT_TICKS; tick++) await nextTick() // past the restore of the second event
      return { atSecondSnapshot, afterWindow: count() }
    }, c.content)
    assert.deepEqual(mounted, { atSecondSnapshot: 0, afterWindow: 0 })
    await settle(page)
    assert.equal(await page.locator(c.overlay).count(), 0)
    assert.equal(await scrollLocked(page), false)
    assert.equal(await page.locator(trigger(c)).first().getAttribute("aria-expanded"), "false")
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
    const host = document.querySelector('[data-controller~="chadcn--dialog"]');
    host.querySelectorAll("template[data-chadcn--dialog-template]").forEach((t) => t.setAttribute("data-chadcn--dialog-options", JSON.stringify({ forceMount: true })));
    host.setAttribute("data-controller", "");
    requestAnimationFrame(() => { host.setAttribute("data-controller", "chadcn--dialog"); resolve(); });
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

// A controlled forceMount dialog that the app closes while the restore is pending (inside the two timer ticks after before-cache)
// must get its forceMount parts back: #sync() is a no-op by then, so only the remount loop can mount them (re-audit R106-2).
browserTest("dialog: a controlled forceMount dialog closed inside the restore window keeps its forceMount parts", async ({ open }) => {
  const page = await open("closed__rest", "dialog");
  const host = '[data-controller~="chadcn--dialog"]';
  await page.evaluate((host) => new Promise((resolve) => {
    const el = document.querySelector(host);
    el.querySelectorAll("template[data-chadcn--dialog-template]").forEach((t) => t.setAttribute("data-chadcn--dialog-options", JSON.stringify({ forceMount: true })));
    el.setAttribute("data-chadcn--dialog-controlled-value", "true");
    el.setAttribute("data-controller", "");
    requestAnimationFrame(() => { el.setAttribute("data-controller", "chadcn--dialog"); resolve(); });
  }), host);
  await settle(page);
  const parts = () => page.locator("[data-slot=dialog-content], [data-slot=dialog-overlay]");
  const closedCount = await parts().count();
  const lockedWhileClosed = await scrollLocked(page); // Radix keeps RemoveScroll on a mounted modal content, open or not
  assert.ok(closedCount >= 1, "precondition: forceMount parts are mounted while closed");
  await page.evaluate((host) => document.querySelector(host).setAttribute("data-chadcn--dialog-open-value", "true"), host);
  await page.waitForSelector("[data-slot=dialog-content][data-state=open]");
  await settle(page);
  await page.evaluate(async (host) => {
    document.dispatchEvent(new Event("turbo:before-cache"));
    document.querySelector(host).setAttribute("data-chadcn--dialog-open-value", "false"); // the app closes it inside the window
    for (let tick = 0; tick < 3; tick++) await new Promise((resolve) => setTimeout(resolve));
  }, host);
  await settle(page);
  assert.equal(await parts().count(), closedCount, "the forceMount parts are mounted again");
  assert.deepEqual(await parts().evaluateAll((els) => els.map((el) => el.getAttribute("data-state"))), Array(closedCount).fill("closed"));
  assert.equal(await scrollLocked(page), lockedWhileClosed);
});

// The destructive Action comes before Cancel in the DOM, so only the redirect to Cancel (not the first tabbable) passes.
browserTest("alert-dialog: open on first paint focuses the Cancel button, not the first tabbable", async ({ open }) => {
  const page = await open("closed__rest", "alert-dialog");
  await page.evaluate(() => {
    const host = document.querySelector('[data-controller~="chadcn--alert-dialog"]');
    const restored = host.cloneNode(true);
    const content = restored.querySelector("template[data-chadcn--dialog-template]").content;
    const cancel = content.querySelector("[data-chadcn--alert-dialog-part=cancel]");
    const action = content.querySelector("[data-slot=alert-dialog-action]");
    cancel.before(action);
    restored.setAttribute("data-chadcn--alert-dialog-open-value", "true");
    host.replaceWith(restored);
  });
  await page.waitForSelector("[data-slot=alert-dialog-content]");
  await settle(page);
  const active = await page.evaluate(() => document.activeElement?.getAttribute("data-chadcn--alert-dialog-part"));
  assert.equal(active, "cancel");
});

// Hover card: Turbo keeps the page for a #hash visit, so a card the page renders open (controlled, or default_open and not closed
// by the user) is open again once the snapshot is taken; the snapshot itself never holds it (stimulus R3, radix-stimulus R10).
// These staying-page cases sit next to the dialog ones because they exercise the same turbo_cache restore window.
const HOVER_TRIGGER = "[data-slot=hover-card-trigger]"
const HOVER_CONTENT = "[data-slot=hover-card-content]"

// Mounted cards on the tick Turbo snapshots in (after the last event) and once the restore window has passed.
const hoverCardAcrossSnapshot = (page, { events = 1 } = {}) => page.evaluate(async ({ content, events }) => {
  const nextTick = () => new Promise((resolve) => setTimeout(resolve))
  const mounted = () => document.querySelectorAll(content).length
  for (let round = 1; round <= events; round++) {
    document.dispatchEvent(new Event("turbo:before-cache"))
    await nextTick() // the snapshot tick; a further event lands inside the restore window
  }
  const atSnapshot = mounted()
  const { SNAPSHOT_TICKS } = await import("chadcn/primitives/turbo_cache")
  for (let tick = 0; tick <= SNAPSHOT_TICKS; tick++) await nextTick()
  return { atSnapshot, afterWindow: mounted() }
}, { content: HOVER_CONTENT, events })

const HOVER_OPEN_CASES = [
  { scenario: "controlled-open-true__stays-open", events: 1 },
  { scenario: "default-open__open", events: 1 },
  { scenario: "default-open__open", events: 2 } // the second teardown finds the card reset: only the carried state keeps it
]

for (const { scenario, events } of HOVER_OPEN_CASES) {
  browserTest(`hover-card (${scenario}): a card rendered open is open again after ${events} before-cache on a staying page`, async ({ open }) => {
    const page = await open(scenario, "hover-card")
    await page.mouse.move(2, 2) // no pointer re-arm: only the reconcile can bring the card back
    await page.waitForSelector(HOVER_CONTENT)
    await settle(page)
    assert.deepEqual(await hoverCardAcrossSnapshot(page, { events }), { atSnapshot: 0, afterWindow: 1 })
    assert.equal(await page.locator(HOVER_TRIGGER).first().getAttribute("data-state"), "open")
  })
}

// The negative twin of HOVER_OPEN_CASES: with two events the carried state, not the second event itself, decides (a carry of
// `pending` alone re-opens the card the user closed).
for (const events of [1, 2]) {
  browserTest(`hover-card: a default-open card the user closed stays closed after ${events} before-cache on a staying page`, async ({ open }) => {
    const page = await open("default-open__open", "hover-card")
    await page.mouse.move(2, 2)
    await page.waitForSelector(HOVER_CONTENT)
    await page.keyboard.press("Escape")
    await page.waitForSelector(HOVER_CONTENT, { state: "detached" })
    assert.deepEqual(await hoverCardAcrossSnapshot(page, { events }), { atSnapshot: 0, afterWindow: 0 })
    assert.equal(await page.locator(HOVER_TRIGGER).first().getAttribute("data-state"), "closed")
  })
}

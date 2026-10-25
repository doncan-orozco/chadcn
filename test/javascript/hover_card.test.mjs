import { browserTest } from "./harness.mjs";
import { assert, eventLog, recordEvents, settle } from "./support.mjs";
import { positioningTests } from "./positioning.mjs";

browserTest.component = "hover-card";
const trigger = "[data-slot=hover-card-trigger]";
const content = "[data-slot=hover-card-content]";
const isOpen = (page) => page.locator(content).count().then((n) => n > 0);
// The trigger is an <a> without href (not focusable), so hover opens it after the open delay (700ms).
const open = async (page) => { await page.mouse.move(2, 2); await page.hover(trigger); await page.waitForSelector(content, { timeout: 5000 }); await settle(page); };
const close = async (page) => { await page.keyboard.press("Escape"); await page.waitForSelector(content, { state: "detached" }); };
// turbo:before-cache resets the hover intent (re-audit R106-3). The controller is reconnected with short delays so the waits
// stay short: open 100 ms, close 5 s by default (a re-hover inside the close delay is what a stale open flag used to swallow).
const reconnectWithDelays = (page, { openDelay = 100, closeDelay = 5000 } = {}) => page.evaluate(({ openDelay, closeDelay }) => new Promise((resolve) => {
  const host = document.querySelector('[data-controller~="chadcn--hover-card"]');
  host.setAttribute("data-chadcn--hover-card-open-delay-value", String(openDelay));
  host.setAttribute("data-chadcn--hover-card-close-delay-value", String(closeDelay));
  host.setAttribute("data-controller", "");
  requestAnimationFrame(() => { host.setAttribute("data-controller", "chadcn--hover-card"); resolve(); });
}), { openDelay, closeDelay });
const dispatchBeforeCache = (page) => page.evaluate(async () => {
  document.dispatchEvent(new Event("turbo:before-cache"));
  for (let tick = 0; tick < 3; tick++) await new Promise((resolve) => setTimeout(resolve));
});

// Open delay 0: a pointerenter that is not ignored arms a 0 ms timer, which fires on the next timer tick, and settle() waits past it.
// With the default 700 ms the test would need a fixed wait longer than the delay to prove that nothing opens.
browserTest("hover-card: touch input never opens it (pointerenter is ignored for pointerType touch)", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await reconnectWithDelays(page, { openDelay: 0 });
  await settle(page);
  const box = await page.locator(trigger).boundingBox();
  await page.touchscreen.tap(box.x + box.width / 2, box.y + box.height / 2);
  await page.evaluate(() => document.querySelector("[data-slot=hover-card-trigger]").dispatchEvent(new PointerEvent("pointerenter", { pointerType: "touch" })));
  await settle(page);
  assert.equal(await isOpen(page), false);
}, { touch: true });

browserTest("hover-card: a mouse pointerenter opens it after the delay (control for the touch test)", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await reconnectWithDelays(page, { openDelay: 0 });
  await settle(page);
  await page.hover(trigger);
  await page.waitForSelector(content, { timeout: 5000 });
});

browserTest("hover-card: a caller preventDefault on escape-key-down keeps it open", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await recordEvents(page, "chadcn--hover-card", { prevent: ["escape-key-down"] });
  await open(page);
  await page.keyboard.press("Escape");
  await settle(page);
  assert.ok(await isOpen(page));
  assert.deepEqual((await eventLog(page)).filter((e) => e.name === "escape-key-down").map((e) => e.cancelable), [true]);
});

browserTest("hover-card: open-change fires for every change", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await recordEvents(page, "chadcn--hover-card");
  await open(page);
  await close(page);
  assert.deepEqual((await eventLog(page)).filter((e) => e.name === "open-change").map((e) => e.open), [true, false]);
});

for (const prevented of ["pointer-down-outside", "interact-outside"]) {
  browserTest(`hover-card: a caller preventDefault on ${prevented} keeps it open after an outside click`, async ({ open: openPage }) => {
    const page = await openPage("default__closed");
    await recordEvents(page, "chadcn--hover-card", { prevent: [prevented] });
    await open(page);
    await page.click("[data-testid=outside]");
    await settle(page);
    assert.ok(await isOpen(page), `${prevented} prevented`);
  });
}

positioningTests(browserTest, {
  component: "hover-card", scenario: "default__closed", template: "template[data-chadcn--hover-card-template]", controller: "chadcn--hover-card", trigger, content, open, close
});

browserTest("hover-card: a controlled open value is reconciled when it changes", async ({ open: openPage }) => {
  const page = await openPage("controlled-open-false__stays-closed");
  const set = (value) => page.evaluate(({ selector, value }) => document.querySelector(selector).setAttribute("data-chadcn--hover-card-open-value", value), { selector: '[data-controller~="chadcn--hover-card"]', value: String(value) });
  assert.equal(await isOpen(page), false);
  await set(true);
  await page.waitForSelector(content);
  assert.equal(await page.locator(trigger).getAttribute("data-state"), "open");
  await set(false);
  await page.waitForSelector(content, { state: "detached" });
  assert.equal(await page.locator(trigger).getAttribute("data-state"), "closed");
});

browserTest("hover-card: a hover-opened card torn down by before-cache opens again on the next hover (no stale open flag)", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await reconnectWithDelays(page);
  await settle(page);
  await open(page);
  await page.mouse.move(2, 2); // the close delay (5 s) is pending: the intent still says open
  await dispatchBeforeCache(page);
  assert.equal(await isOpen(page), false, "the snapshot holds no card");
  await page.hover(trigger);
  await page.waitForSelector(content, { timeout: 2000 });
  assert.equal(await page.locator(trigger).getAttribute("data-state"), "open");
});

browserTest("hover-card: after before-cache the card is re-armed from the pointer still on the trigger", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await reconnectWithDelays(page);
  await settle(page);
  await page.mouse.move(2, 2);
  await page.hover(trigger);
  await dispatchBeforeCache(page);
  assert.equal(await isOpen(page), false, "nothing is mounted inside the snapshot window");
  await page.waitForSelector(content, { timeout: 2000 }); // the pointer stayed: the card comes back after the open delay (re-arm)
  assert.equal(await page.locator(trigger).getAttribute("data-state"), "open");
});

// The open timer is armed (0 ms) right before the event, so without the drop it fires on the tick Turbo snapshots in and mounts the
// card into the snapshot. The pointer and the focus are elsewhere, so no re-arm follows either.
browserTest("hover-card: before-cache drops a pending open timer, so no card is mounted into the snapshot", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await page.mouse.move(2, 2);
  await reconnectWithDelays(page, { openDelay: 0 });
  await settle(page);
  const mounted = await page.evaluate(async () => {
    const count = () => document.querySelectorAll("[data-slot=hover-card-content]").length;
    const host = document.querySelector('[data-controller~="chadcn--hover-card"]');
    host.dispatchEvent(new PointerEvent("pointerenter", { pointerType: "mouse" })); // arms the open timer
    document.dispatchEvent(new Event("turbo:before-cache"));
    await new Promise((resolve) => setTimeout(resolve)); // the snapshot tick
    const atSnapshot = count();
    for (let tick = 0; tick < 2; tick++) await new Promise((resolve) => setTimeout(resolve));
    return { atSnapshot, afterWindow: count() };
  });
  assert.deepEqual(mounted, { atSnapshot: 0, afterWindow: 0 }, "the pending open timer was dropped");
  assert.equal(await page.locator(trigger).getAttribute("data-state"), "closed");
});

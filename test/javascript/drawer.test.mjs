import { browserTest } from "./harness.mjs";
import { assert, host, settle } from "./support.mjs";

// What the parity scenarios cannot express: the public events and their detail, the cancelable callbacks vaul gives Radix, the
// snap-point variable, the lifecycle (disconnect restores body, html and the scaled wrapper) and controlled values. Drag distances,
// resets, closings and the DOM around them are compared against the oracle by the scenarios.
browserTest.component = "drawer";
const trigger = "[data-slot=drawer-trigger]";
const content = "[data-slot=drawer-content]";
const overlay = "[data-slot=drawer-overlay]";
const bar = "[data-slot=drawer-content] > div:first-child";
const controller = "chadcn--drawer";

// Records every public event of the controller (name, detail without DOM objects, cancelable, defaultPrevented when it ran).
const record = (page, { prevent = [] } = {}) => page.evaluate(({ prevent }) => {
  window.__drawer = [];
  for (const name of ["open-change", "drag", "release", "close", "animation-end", "active-snap-point-change", "open-auto-focus", "close-auto-focus", "escape-key-down", "pointer-down-outside", "focus-outside"]) {
    document.addEventListener(`chadcn--drawer:${name}`, (event) => {
      const { originalEvent, ...detail } = event.detail ?? {};
      window.__drawer.push({ name, detail, cancelable: event.cancelable, prevented: event.defaultPrevented });
      if (prevent.includes(name)) event.preventDefault();
    });
  }
}, { prevent });
const log = (page, name) => page.evaluate((wanted) => window.__drawer.filter((e) => e.name === wanted), name);
const names = (page) => page.evaluate(() => window.__drawer.map((e) => e.name));
// Opens and waits for the controller's own animation-end {open: true} (500 ms after the change), not for a fixed delay.
const openDrawer = async (page) => {
  await page.evaluate(() => {
    window.__drawerOpened = false;
    document.addEventListener("chadcn--drawer:animation-end", (event) => { if (event.detail.open) window.__drawerOpened = true; }, { once: true });
  });
  await page.click(trigger);
  await page.waitForSelector(content);
  await page.waitForFunction(() => window.__drawerOpened === true);
};
const drag = async (page, dy, { steps = 5, hold = 0 } = {}) => {
  const box = await page.locator(bar).boundingBox();
  const x = box.x + box.width / 2;
  const y = box.y + box.height / 2;
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.mouse.move(x, y + dy / 2, { steps });
  await page.mouse.move(x, y + dy, { steps });
  if (hold) await page.waitForTimeout(hold); // the pause before release is the gesture's release-velocity input, not a wait for the UI
  await page.mouse.up();
};

browserTest("drawer: open-change carries the requested state and animation-end follows 500 ms after each change", async ({ open }) => {
  const page = await open("open__direction-bottom-default");
  await record(page);
  await openDrawer(page);
  await page.keyboard.press("Escape");
  await page.waitForSelector(content, { state: "detached" });
  assert.deepEqual((await log(page, "open-change")).map((e) => e.detail), [{ open: true }, { open: false }]);
  await page.waitForFunction(() => window.__drawer.filter((e) => e.name === "animation-end").length === 2);
  assert.deepEqual((await log(page, "animation-end")).map((e) => e.detail), [{ open: true }, { open: false }]);
});

browserTest("drawer: dismissible false ignores Escape without an open-change", async ({ open }) => {
  const page = await open("dismissible-false__escape-stays-open");
  await record(page);
  await openDrawer(page);
  await page.keyboard.press("Escape");
  await settle(page);
  assert.equal(await page.locator(content).count(), 1);
  assert.ok((await log(page, "escape-key-down")).length >= 1);
  assert.deepEqual((await log(page, "open-change")).map((e) => e.detail), [{ open: true }]);
});

browserTest("drawer: dismissible true (control) closes on Escape", async ({ open }) => {
  const page = await open("open__direction-bottom-default");
  await record(page);
  await openDrawer(page);
  await page.keyboard.press("Escape");
  await page.waitForSelector(content, { state: "detached" });
  assert.deepEqual((await log(page, "open-change")).map((e) => e.detail), [{ open: true }, { open: false }]);
});

browserTest("drawer: open-auto-focus is cancelable and unprevented for listeners, yet nothing is focused by default", async ({ open }) => {
  const page = await open("open__direction-bottom-default");
  await record(page);
  await openDrawer(page);
  const [event] = await log(page, "open-auto-focus");
  assert.equal(event.cancelable, true);
  assert.equal(event.prevented, false);
  assert.equal(await page.evaluate(() => document.activeElement.dataset.slot), "drawer-trigger");
});

browserTest("drawer: auto_focus focuses the first tabbable element of the content", async ({ open }) => {
  const page = await open("focus__auto-focus-true");
  await openDrawer(page);
  assert.ok(await page.evaluate(() => document.querySelector("[data-slot=drawer-content]").contains(document.activeElement)));
});

browserTest("drawer: a drag past the threshold fires drag, then release open false and close, and unmounts", async ({ open }) => {
  const page = await open("open__direction-bottom-default");
  await record(page);
  await openDrawer(page);
  await drag(page, 250, { hold: 300 });
  await page.waitForSelector(content, { state: "detached" });
  const order = await names(page);
  assert.ok(order.indexOf("drag") < order.indexOf("release"), order.join(","));
  assert.ok(order.includes("close"));
  assert.deepEqual((await log(page, "release")).map((e) => e.detail), [{ open: false }]);
  const [first] = await log(page, "drag");
  assert.equal(typeof first.detail.percentageDragged, "number");
  assert.deepEqual((await log(page, "open-change")).map((e) => e.detail), [{ open: true }, { open: false }]);
});

browserTest("drawer: a short drag releases open true and the content returns to translate3d(0, 0, 0)", async ({ open }) => {
  const page = await open("open__direction-bottom-default");
  await record(page);
  await openDrawer(page);
  await drag(page, 30, { hold: 400 });
  assert.deepEqual((await log(page, "release")).map((e) => e.detail), [{ open: true }]);
  assert.equal(await page.locator(content).evaluate((node) => node.style.transform), "translate3d(0px, 0px, 0px)");
  assert.equal(await page.locator(content).evaluate((node) => node.classList.contains("vaul-dragging")), false);
});

browserTest("drawer: a controlled open only reports the request and follows the value", async ({ open }) => {
  const page = await open("controlled__open-false-stays-closed");
  await record(page);
  await page.click(trigger);
  await settle(page);
  assert.equal(await page.locator(content).count(), 0);
  assert.deepEqual((await log(page, "open-change")).map((e) => e.detail), [{ open: true }]);
  await page.locator(host(controller)).evaluate((node) => node.setAttribute("data-chadcn--drawer-open-value", "true"));
  await page.waitForSelector(content);
  assert.equal(await page.locator(trigger).getAttribute("aria-expanded"), "true");
});

browserTest("drawer: snap points place the content with --snap-point-height and report the active point", async ({ open }) => {
  const page = await open("snap-points__open");
  await record(page);
  await openDrawer(page);
  const height = await page.evaluate(() => window.innerHeight);
  assert.equal(await page.locator(content).evaluate((node) => node.style.getPropertyValue("--snap-point-height")), `${height - height * 0.5}px`);
  assert.equal(await page.locator(content).getAttribute("data-vaul-delayed-snap-points"), "true");
  await drag(page, -300, { steps: 3 });
  await page.waitForFunction(() => window.__drawer.some((e) => e.name === "active-snap-point-change" && e.detail.activeSnapPoint === 1));
  assert.equal(await page.locator(content).getAttribute("data-vaul-snap-points"), "true");
});

browserTest("drawer: modal false renders no overlay and leaves the page clickable", async ({ open }) => {
  const page = await open("modal-false__open");
  await openDrawer(page);
  assert.equal(await page.locator(overlay).count(), 0);
  assert.equal(await page.evaluate(() => document.body.style.pointerEvents), "auto");
  assert.equal(await page.locator(content).getAttribute("data-state"), "open");
});

browserTest("drawer: a right-click outside never dismisses", async ({ open }) => {
  const page = await open("open__direction-bottom-default");
  await openDrawer(page);
  await page.locator(overlay).click({ button: "right", position: { x: 10, y: 10 }, force: true });
  await settle(page);
  assert.equal(await page.locator(content).getAttribute("data-state"), "open");
  // Control: a primary press on the same overlay does dismiss.
  await page.locator(overlay).click({ position: { x: 10, y: 10 }, force: true });
  await page.waitForSelector(content, { state: "detached" });
});

browserTest("drawer: disconnect while open releases scroll lock, timers, frames and body styles", async ({ open }) => {
  const page = await open("open__direction-bottom-default");
  await openDrawer(page);
  const state = () => page.evaluate(({ controller, host }) => {
    const ctrl = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector(host), controller);
    return { preventingScroll: ctrl.preventingScroll, pending: ctrl.timers.size + ctrl.frames.size, position: document.body.style.position };
  }, { controller, host: host(controller) });
  // Control: the lock is held while open.
  assert.equal((await state()).preventingScroll, true);
  await page.evaluate(({ controller, host }) => {
    window.__ctrl = window.Stimulus.getControllerForElementAndIdentifier(document.querySelector(host), controller);
    document.querySelector(host).remove();
  }, { controller, host: host(controller) });
  const after = await page.evaluate(() => ({
    preventingScroll: window.__ctrl.preventingScroll, pending: window.__ctrl.timers.size + window.__ctrl.frames.size, position: document.body.style.position
  }));
  assert.equal(after.preventingScroll, false);
  assert.equal(after.pending, 0);
  assert.equal(after.position, "");
});

browserTest("drawer: disconnect removes the portaled nodes and restores body, html and the scaled wrapper", async ({ open }) => {
  const page = await open("scale-background__open");
  await openDrawer(page);
  const wrapper = "[data-vaul-drawer-wrapper]";
  assert.match(await page.locator(wrapper).getAttribute("style"), /scale\(/);
  assert.equal(await page.evaluate(() => document.documentElement.style.scrollBehavior), "auto");
  await page.locator(host(controller)).evaluate((node) => node.remove());
  await settle(page);
  assert.equal(await page.locator(content).count(), 0);
  assert.equal(await page.locator(overlay).count(), 0);
  assert.equal(await page.evaluate(() => document.documentElement.style.scrollBehavior), "");
  assert.doesNotMatch((await page.locator(wrapper).getAttribute("style")) ?? "", /scale\(/);
  assert.equal(await page.evaluate(() => document.body.style.background), "");
});

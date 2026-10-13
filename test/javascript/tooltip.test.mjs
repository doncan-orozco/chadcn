import { browserTest } from "./harness.mjs";
import { assert, eventLog, recordEvents, settle } from "./support.mjs";
import { positioningTests } from "./positioning.mjs";

browserTest.component = "tooltip";
const trigger = "[data-slot=tooltip-trigger]";
const content = "[data-slot=tooltip-content]";
const isOpen = (page) => page.locator(content).count().then((n) => n > 0);
// Keyboard focus opens instantly (no hover timers), like the keyboard-open scenarios.
const open = async (page) => { await page.focus(trigger); await page.waitForSelector(content); await settle(page); };
const close = async (page) => { await page.keyboard.press("Escape"); await page.waitForSelector(content, { state: "detached" }); };
const tap = async (page) => {
  const box = await page.locator(trigger).boundingBox();
  await page.touchscreen.tap(box.x + box.width / 2, box.y + box.height / 2);
};

browserTest("tooltip: touch input never opens it (pointermove is ignored for pointerType touch)", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await tap(page);
  await page.evaluate(() => document.querySelector("[data-slot=tooltip-trigger]").dispatchEvent(new PointerEvent("pointermove", { pointerType: "touch", bubbles: true })));
  await page.waitForTimeout(500);
  assert.equal(await isOpen(page), false);
}, { touch: true });

browserTest("tooltip: a mouse pointermove opens it (control for the touch test)", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await page.hover(trigger);
  await page.waitForSelector(content);
});

browserTest("tooltip: scrolling the page closes an open tooltip", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await page.evaluate(() => (document.body.style.minHeight = "4000px"));
  await open(page);
  await page.evaluate(() => window.scrollTo(0, 120));
  await page.waitForSelector(content, { state: "detached" });
});

browserTest("tooltip: a caller preventDefault on escape-key-down keeps it open", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await recordEvents(page, "shadcn--tooltip", { prevent: ["escape-key-down"] });
  await open(page);
  await page.keyboard.press("Escape");
  await settle(page);
  assert.ok(await isOpen(page));
  assert.deepEqual((await eventLog(page)).filter((e) => e.name === "escape-key-down").map((e) => e.cancelable), [true]);
});

browserTest("tooltip: open-change fires for every change", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await recordEvents(page, "shadcn--tooltip");
  await open(page);
  await close(page);
  assert.deepEqual((await eventLog(page)).filter((e) => e.name === "open-change").map((e) => e.open), [true, false]);
});

positioningTests(browserTest, {
  component: "tooltip", scenario: "default__closed", template: "template[data-shadcn--tooltip-template]", controller: "shadcn--tooltip", trigger, content, open, close
});

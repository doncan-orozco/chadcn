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

browserTest("hover-card: touch input never opens it (pointerenter is ignored for pointerType touch)", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  const box = await page.locator(trigger).boundingBox();
  await page.touchscreen.tap(box.x + box.width / 2, box.y + box.height / 2);
  await page.evaluate(() => document.querySelector("[data-slot=hover-card-trigger]").dispatchEvent(new PointerEvent("pointerenter", { pointerType: "touch" })));
  await page.waitForTimeout(1100);
  assert.equal(await isOpen(page), false);
}, { touch: true });

browserTest("hover-card: a mouse pointerenter opens it after the delay (control for the touch test)", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await page.hover(trigger);
  await page.waitForSelector(content, { timeout: 5000 });
});

browserTest("hover-card: touchstart on the trigger is not default-prevented (Radix's handler is passive, so a no-op)", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  const prevented = await page.evaluate(() => {
    const event = new Event("touchstart", { bubbles: true, cancelable: true });
    document.querySelector("[data-slot=hover-card-trigger]").dispatchEvent(event);
    return event.defaultPrevented;
  });
  assert.equal(prevented, false);
});

browserTest("hover-card: a caller preventDefault on escape-key-down keeps it open", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await recordEvents(page, "shadcn--hover-card", { prevent: ["escape-key-down"] });
  await open(page);
  await page.keyboard.press("Escape");
  await settle(page);
  assert.ok(await isOpen(page));
  assert.deepEqual((await eventLog(page)).filter((e) => e.name === "escape-key-down").map((e) => e.cancelable), [true]);
});

browserTest("hover-card: open-change fires for every change", async ({ open: openPage }) => {
  const page = await openPage("default__closed");
  await recordEvents(page, "shadcn--hover-card");
  await open(page);
  await close(page);
  assert.deepEqual((await eventLog(page)).filter((e) => e.name === "open-change").map((e) => e.open), [true, false]);
});

for (const prevented of ["pointer-down-outside", "interact-outside"]) {
  browserTest(`hover-card: a caller preventDefault on ${prevented} keeps it open after an outside click`, async ({ open: openPage }) => {
    const page = await openPage("default__closed");
    await recordEvents(page, "shadcn--hover-card", { prevent: [prevented] });
    await open(page);
    await page.click("[data-testid=outside]");
    await settle(page);
    assert.ok(await isOpen(page), `${prevented} prevented`);
  });
}

positioningTests(browserTest, {
  component: "hover-card", scenario: "default__closed", template: "template[data-shadcn--hover-card-template]", controller: "shadcn--hover-card", trigger, content, open, close
});

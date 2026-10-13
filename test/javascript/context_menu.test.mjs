import { browserTest } from "./harness.mjs";
import { assert, settle } from "./support.mjs";

browserTest.component = "context-menu";
const trigger = "[data-slot=context-menu-trigger]";
const content = "[data-slot=context-menu-content]";
const isOpen = (page) => page.locator(content).count().then((n) => n > 0);

// The runner has no touch/pen input, so the pointer events are dispatched directly on the trigger.
const pointer = (page, type, pointerType, at = { x: 200, y: 160 }) => page.evaluate(({ type, pointerType, at, trigger }) => {
  document.querySelector(trigger).dispatchEvent(new PointerEvent(type, { pointerType, clientX: at.x, clientY: at.y, bubbles: true, cancelable: true }));
}, { type, pointerType, at, trigger });

for (const pointerType of ["touch", "pen"]) {
  browserTest(`context-menu: a ${pointerType} press held for 700ms opens the menu at the press point`, async ({ open }) => {
    const page = await open("closed__default");
    await pointer(page, "pointerdown", pointerType, { x: 200, y: 160 });
    await page.waitForTimeout(500);
    assert.equal(await isOpen(page), false, "still closed before the long-press delay");
    await page.waitForSelector(content, { timeout: 2000 });
    await settle(page);
    const box = await page.locator(content).boundingBox();
    assert.ok(Math.abs(box.x - 202) <= 1 && Math.abs(box.y - 160) <= 30, `content at ${box.x},${box.y}`);
  });

  for (const release of ["pointerup", "pointermove", "pointercancel"]) {
    browserTest(`context-menu: ${release} before the delay cancels the ${pointerType} long press`, async ({ open }) => {
      const page = await open("closed__default");
      await pointer(page, "pointerdown", pointerType);
      await page.waitForTimeout(300);
      await pointer(page, release, pointerType);
      await page.waitForTimeout(700);
      assert.equal(await isOpen(page), false);
    });
  }
}

browserTest("context-menu: a mouse pointerdown does not start a long press", async ({ open }) => {
  const page = await open("closed__default");
  await pointer(page, "pointerdown", "mouse");
  await page.waitForTimeout(900);
  assert.equal(await isOpen(page), false);
});

browserTest("context-menu: a touch press on an open menu's trigger closes it before the new long press", async ({ open }) => {
  const page = await open("closed__default");
  await page.click(trigger, { button: "right" });
  await page.waitForSelector(content);
  await pointer(page, "pointerdown", "touch");
  await page.waitForSelector(content, { state: "detached" });
});

browserTest("context-menu: a disabled trigger ignores the long press", async ({ open }) => {
  const page = await open("trigger__disabled");
  await pointer(page, "pointerdown", "touch");
  await page.waitForTimeout(900);
  assert.equal(await isOpen(page), false);
});

browserTest("context-menu: disconnecting during a long press clears the timer", async ({ open }) => {
  const page = await open("closed__default");
  await pointer(page, "pointerdown", "touch");
  await page.evaluate(() => document.querySelector("[data-slot=context-menu-trigger]").remove());
  await page.waitForTimeout(900);
  assert.equal(await isOpen(page), false);
});

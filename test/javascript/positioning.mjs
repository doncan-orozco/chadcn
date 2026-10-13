// Positioner options shared by every floating component (popover, hover-card, tooltip): the runner only compares the
// default options, so hide_when_detached, update_position_strategy and collision_boundary are exercised here.
import { assert, reconnectWithOptions, settle } from "./support.mjs";

const rect = (page, selector) => page.locator(selector).evaluate((el) => {
  const r = el.getBoundingClientRect();
  return { x: r.x, y: r.y, width: r.width, height: r.height };
});

// `open` brings the content up and `content` is its slot selector; the wrapper positioned by floating-ui is its parent.
export function positioningTests(test, { component, scenario, template, controller, trigger, content, open, close }) {
  const reconnect = (page, options) => reconnectWithOptions(page, { template, controller, options });

  // The trigger is moved out of the viewport with a transform (a scroll would close a tooltip), and "always" re-measures it.
  for (const hideWhenDetached of [true, false]) {
    test(`${component}: hide_when_detached=${hideWhenDetached} ${hideWhenDetached ? "hides" : "keeps visible"} the content once the trigger leaves the viewport`, async ({ open: openPage }) => {
      const page = await openPage(scenario);
      await reconnect(page, { hideWhenDetached, updatePositionStrategy: "always" });
      await open(page);
      const visibility = () => page.locator(content).locator("xpath=..").evaluate((el) => el.style.visibility);
      assert.notEqual(await visibility(), "hidden");
      await page.locator(trigger).evaluate((el) => (el.style.transform = "translateY(-2000px)"));
      await page.waitForTimeout(200);
      assert.equal(await visibility() === "hidden", hideWhenDetached);
    });
  }

  // floating-ui's "always" strategy re-measures on every animation frame; "optimized" only on observed layout changes
  // (its IntersectionObserver would also notice a transform move, so frame polling is what tells them apart).
  test(`${component}: update_position_strategy "always" polls every frame, "optimized" does not`, async ({ open: openPage }) => {
    for (const [strategy, polls] of [["always", true], ["optimized", false]]) {
      const page = await openPage(scenario);
      await reconnect(page, { updatePositionStrategy: strategy });
      await open(page);
      await settle(page);
      const frames = await page.evaluate(() => new Promise((resolve) => {
        let count = 0;
        const original = window.requestAnimationFrame;
        window.requestAnimationFrame = (callback) => { count += 1; return original.call(window, callback); };
        setTimeout(() => { window.requestAnimationFrame = original; resolve(count); }, 300);
      }));
      if (polls) assert.ok(frames >= 10, `${strategy}: ${frames} frames requested in 300ms`);
      else assert.ok(frames <= 2, `${strategy}: ${frames} frames requested in 300ms`);
      await page.context().close();
    }
  });

  test(`${component}: collision_boundary keeps the content inside the boundary element`, async ({ open: openPage }) => {
    const page = await openPage(scenario);
    // Control: the same placement without a boundary runs past x = 640 (the trigger sits in the middle of a 1280px page).
    await reconnect(page, { side: "right", align: "center", collisionPadding: 0 });
    await open(page);
    const free = await rect(page, content);
    assert.ok(free.x + free.width > 650, `control: content right edge ${free.x + free.width}`);
    await close(page);
    await page.evaluate(() => document.activeElement?.blur());
    await page.evaluate(() => {
      const bounds = document.createElement("div");
      bounds.id = "collision-bounds";
      bounds.style.cssText = "position:fixed;left:0;top:0;width:640px;height:720px;pointer-events:none";
      document.body.append(bounds);
    });
    await reconnect(page, { collisionBoundary: "#collision-bounds", side: "right", align: "center", collisionPadding: 0 });
    await open(page);
    const box = await rect(page, content);
    assert.ok(box.x + box.width <= 640.5, `content right edge ${box.x + box.width} must not pass the boundary at 640`);
  });
}

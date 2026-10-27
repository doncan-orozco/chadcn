import { browserTest } from "./harness.mjs";
import { assert, settle } from "./support.mjs";

browserTest.component = "carousel";
const root = "[data-slot=carousel]";
const container = "[data-slot=carousel-content] > div";
const next = "[data-slot=carousel-next]";
const previous = "[data-slot=carousel-previous]";

const transform = (page) => page.locator(container).evaluate((node) => node.style.transform);
// Counts the select events and waits for the animation to settle (the engine emits settle at rest).
const record = (page) => page.evaluate(() => {
  window.__carousel = { selects: [], settles: 0, api: null };
  const host = document.querySelector("[data-slot=carousel]");
  host.addEventListener("chadcn--carousel:select", (event) => window.__carousel.selects.push(event.detail));
  host.addEventListener("chadcn--carousel:settle", () => { window.__carousel.settles += 1; });
});
const settled = (page, count) => page.waitForFunction((n) => window.__carousel.settles >= n, count);
const index = (page) => page.locator(root).evaluate((node) => {
  const controller = window.Stimulus.getControllerForElementAndIdentifier(node, "chadcn--carousel");
  return controller.api.selectedScrollSnap();
});

browserTest("carousel: connect writes the transform and enables Next only", async ({ open }) => {
  const page = await open("default__rest");
  assert.equal(await transform(page), "translate3d(0px, 0px, 0px)");
  assert.equal(await page.locator(previous).isDisabled(), true);
  assert.equal(await page.locator(next).isDisabled(), false);
});

browserTest("carousel: Next moves one slide, emits select and enables Previous", async ({ open }) => {
  const page = await open("default__rest");
  await record(page);
  await page.click(next);
  await settled(page, 1);
  assert.notEqual(await transform(page), "translate3d(0px, 0px, 0px)");
  assert.deepEqual(await page.evaluate(() => window.__carousel.selects), [{ index: 1, previousIndex: 0 }]);
  assert.equal(await page.locator(previous).isDisabled(), false);
});

browserTest("carousel: ArrowRight and ArrowLeft scroll, ArrowDown is ignored, the keys are prevented", async ({ open }) => {
  const page = await open("default__rest");
  await record(page);
  const prevented = await page.locator(root).evaluate((node) => {
    const fire = (key) => {
      const event = new KeyboardEvent("keydown", { key, bubbles: true, cancelable: true });
      node.dispatchEvent(event);
      return event.defaultPrevented;
    };
    return [fire("ArrowRight"), fire("ArrowDown")];
  });
  assert.deepEqual(prevented, [true, false]);
  await settled(page, 1);
  assert.equal(await index(page), 1);
  await page.locator(root).evaluate((node) => node.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowLeft", bubbles: true, cancelable: true })));
  await settled(page, 2);
  assert.equal(await index(page), 0);
});

browserTest("carousel: a vertical carousel uses the Y axis and the horizontal arrow keys", async ({ open }) => {
  const page = await open("orientation-vertical__rest");
  assert.match(await transform(page), /^translate3d\(0px,/);
  await page.locator(root).evaluate((node) => node.dispatchEvent(new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true })));
  await page.waitForFunction(() => document.querySelector("[data-slot=carousel-previous]").disabled === false);
});

browserTest("carousel: loop keeps both buttons enabled and translates the loop slides", async ({ open }) => {
  const page = await open("opts-loop__rest");
  assert.equal(await page.locator(previous).isDisabled(), false);
  assert.equal(await page.locator(next).isDisabled(), false);
  const withTransform = await page.locator(`${container} > *`).evaluateAll((nodes) => nodes.filter((node) => node.style.transform).length);
  assert.ok(withTransform > 0);
});

browserTest("carousel: a caller disabled value is never touched by the controller", async ({ open }) => {
  const page = await open("next__disabled-prop");
  await settle(page);
  assert.equal(await page.locator(next).isDisabled(), true);
  const open2 = await open("previous__disabled-false-prop");
  assert.equal(await open2.locator(previous).isDisabled(), false);
});

browserTest("carousel: the api event carries the embla-shaped api", async ({ open }) => {
  const page = await open("default__rest");
  const names = await page.locator(root).evaluate((node) => {
    const controller = window.Stimulus.getControllerForElementAndIdentifier(node, "chadcn--carousel");
    return ["canScrollNext", "scrollTo", "scrollSnapList", "slideNodes", "on", "off", "reInit", "destroy"].filter((name) => typeof controller.api[name] === "function");
  });
  assert.equal(names.length, 8);
});

browserTest("carousel: disconnect clears the transform and a reconnect starts from startIndex", async ({ open }) => {
  const page = await open("default__rest");
  await record(page);
  await page.click(next);
  await settled(page, 1);
  assert.equal(await index(page), 1);
  const cleared = await page.locator(root).evaluate(async (node) => {
    const inner = node.querySelector("[data-slot=carousel-content] > div");
    const parent = node.parentNode;
    const after = node.nextSibling;
    node.remove();
    await new Promise((resolve) => setTimeout(resolve));
    const result = inner.hasAttribute("style");
    parent.insertBefore(node, after);
    return result;
  });
  assert.equal(cleared, false);
  await settle(page);
  assert.equal(await index(page), 0);
  assert.equal(await transform(page), "translate3d(0px, 0px, 0px)");
});

browserTest("carousel: mouse drag past the threshold moves to the next slide", async ({ open }) => {
  const page = await open("default__rest");
  await record(page);
  const box = await page.locator("[data-slot=carousel-content]").boundingBox();
  const y = box.y + box.height / 2;
  await page.mouse.move(box.x + box.width - 20, y);
  await page.mouse.down();
  await page.waitForTimeout(300);
  await page.mouse.move(box.x + 20, y, { steps: 10 });
  await page.mouse.up();
  await settled(page, 1);
  assert.equal(await index(page), 1);
});

import { browserTest } from "./harness.mjs";
import { assert } from "./support.mjs";

// What the parity scenarios cannot express: the cancelable key results, the public events and their detail, the api object, the
// lifecycle (disconnect, Turbo cache), value changes and touch input. Transforms, disabled states and click/drag/loop results are
// compared against the oracle by the scenarios.
browserTest.component = "carousel";
const root = "[data-slot=carousel]";
const container = "[data-slot=carousel-content] > div";
const next = "[data-slot=carousel-next]";
const previous = "[data-slot=carousel-previous]";

// Records the public events on the host; `window.__carousel` holds them for waitForFunction.
const record = (page) => page.evaluate(() => {
  window.__carousel = { api: [], select: [], reinit: [], settle: [] };
  const host = document.querySelector("[data-slot=carousel]");
  for (const name of Object.keys(window.__carousel)) {
    host.addEventListener(`chadcn--carousel:${name}`, (event) => window.__carousel[name].push({ ...event.detail, bubbles: event.bubbles }));
  }
});
const count = (page, name, n) => page.waitForFunction(([key, total]) => window.__carousel[key].length >= total, [name, n]);
const controller = (page) => page.locator(root).evaluateHandle((node) => window.Stimulus.getControllerForElementAndIdentifier(node, "chadcn--carousel"));
const index = (page) => page.locator(root).evaluate((node) => window.Stimulus.getControllerForElementAndIdentifier(node, "chadcn--carousel").api.selectedScrollSnap());
const waitIndex = (page, n) => page.waitForFunction((target) => {
  const host = document.querySelector("[data-slot=carousel]");
  return window.Stimulus.getControllerForElementAndIdentifier(host, "chadcn--carousel").api?.selectedScrollSnap() === target;
}, n);
const key = (page, name) => page.locator(root).evaluate((node, keyName) => {
  const event = new KeyboardEvent("keydown", { key: keyName, bubbles: true, cancelable: true });
  node.dispatchEvent(event);
  return event.defaultPrevented;
}, name);

browserTest("carousel: Next emits a bubbling select with the indexes, then settle", async ({ open }) => {
  const page = await open("default__rest");
  await record(page);
  await page.click(next);
  await count(page, "settle", 1);
  assert.deepEqual(await page.evaluate(() => window.__carousel.select), [{ index: 1, previousIndex: 0, bubbles: true }]);
  assert.deepEqual(await page.evaluate(() => window.__carousel.settle), [{ index: 1, bubbles: true }]);
});

browserTest("carousel: ArrowRight and ArrowLeft are prevented and scroll, ArrowDown is ignored", async ({ open }) => {
  const page = await open("default__rest");
  assert.equal(await key(page, "ArrowDown"), false);
  assert.equal(await key(page, "ArrowRight"), true);
  await waitIndex(page, 1);
  assert.equal(await key(page, "ArrowLeft"), true);
  await waitIndex(page, 0);
});

browserTest("carousel: a key is prevented even when the carousel cannot scroll", async ({ open }) => {
  const page = await open("keyboard-arrowleft__at-start");
  assert.equal(await key(page, "ArrowLeft"), true);
  assert.equal(await index(page), 0);
});

browserTest("carousel: the api object has the embla surface and the api event carries it on every rebuild", async ({ open }) => {
  const page = await open("default__rest");
  await record(page);
  await page.locator(root).evaluate((node) => node.setAttribute("data-chadcn--carousel-opts-value", JSON.stringify({ startIndex: 2 })));
  await count(page, "api", 1);
  await waitIndex(page, 2);
  const names = await (await controller(page)).evaluate((ctrl) => ["canScrollNext", "canScrollPrev", "scrollTo", "scrollSnapList", "slideNodes", "on", "off", "reInit", "destroy"].filter((name) => typeof ctrl.api[name] === "function"));
  assert.equal(names.length, 9);
  assert.equal(await page.evaluate(() => typeof window.__carousel.api[0].api.scrollNext), "function");
});

browserTest("carousel: changing the opts value re-inits and an orientation change rebuilds the axis", async ({ open }) => {
  const page = await open("default__rest");
  await page.locator(root).evaluate((node) => node.setAttribute("data-chadcn--carousel-opts-value", JSON.stringify({ startIndex: 3 })));
  await waitIndex(page, 3);
  await page.locator(root).evaluate((node) => node.setAttribute("data-chadcn--carousel-orientation-value", "vertical"));
  await page.waitForFunction((selector) => /^translate3d\(0px, -?\d/.test(document.querySelector(selector).style.transform), container);
});

browserTest("carousel: watchSlides re-inits when a slide is appended", async ({ open }) => {
  const page = await open("default__rest");
  await record(page);
  const before = await page.locator("[data-slot=carousel-item]").count();
  await page.locator(container).evaluate((node) => node.append(node.lastElementChild.cloneNode(true)));
  await count(page, "reinit", 1);
  assert.equal(await (await controller(page)).evaluate((ctrl) => ctrl.api.slideNodes().length), before + 1);
});

browserTest("carousel: a touch drag past the threshold moves to the next slide", async ({ open }) => {
  const page = await open("default__rest");
  await record(page);
  const box = await page.locator("[data-slot=carousel-content]").boundingBox();
  const y = box.y + box.height / 2;
  await page.locator("[data-slot=carousel-content]").evaluate(async (node, [startX, endX, clientY]) => {
    const touch = (x) => new Touch({ identifier: 1, target: node, clientX: x, clientY, pageX: x, pageY: clientY });
    const fire = (type, x) => node.dispatchEvent(new TouchEvent(type, { bubbles: true, cancelable: true, touches: type === "touchend" ? [] : [touch(x)], changedTouches: [touch(x)] }));
    const frame = () => new Promise((resolve) => requestAnimationFrame(resolve));
    fire("touchstart", startX);
    for (let step = 1; step <= 10; step += 1) {
      await frame();
      fire("touchmove", startX + ((endX - startX) * step) / 10);
    }
    fire("touchend", endX);
  }, [box.x + box.width - 20, box.x + 20, y]);
  await waitIndex(page, 1);
}, { touch: true });

browserTest("carousel: disconnect clears the transform and a reconnect starts from startIndex", async ({ open }) => {
  const page = await open("default__rest");
  await page.click(next);
  await waitIndex(page, 1);
  const cleared = await page.locator(root).evaluate(async (node) => {
    const inner = node.querySelector("[data-slot=carousel-content] > div");
    const parent = node.parentNode;
    const after = node.nextSibling;
    node.remove();
    await new Promise((resolve) => requestAnimationFrame(resolve));
    const result = inner.hasAttribute("style");
    parent.insertBefore(node, after);
    return result;
  });
  assert.equal(cleared, false);
  await waitIndex(page, 0);
  await page.waitForFunction((selector) => document.querySelector(selector).style.transform === "translate3d(0px, 0px, 0px)", container);
});

browserTest("carousel: turbo:before-cache restores the server markup and the engine is built again after the snapshot", async ({ open }) => {
  const page = await open("default__rest");
  await page.click(next);
  await waitIndex(page, 1);
  const snapshot = await page.evaluate(() => {
    document.dispatchEvent(new Event("turbo:before-cache"));
    const inner = document.querySelector("[data-slot=carousel-content] > div");
    return {
      style: inner.hasAttribute("style"),
      previous: document.querySelector("[data-slot=carousel-previous]").disabled,
      next: document.querySelector("[data-slot=carousel-next]").disabled,
    };
  });
  assert.deepEqual(snapshot, { style: false, previous: true, next: true });
  await waitIndex(page, 0);
  await page.waitForFunction(() => !document.querySelector("[data-slot=carousel-next]").disabled);
  assert.equal(await page.locator(previous).isDisabled(), true);
});

browserTest("carousel: a caller disabled value is locked and survives the cache restore", async ({ open }) => {
  const page = await open("previous__disabled-false-prop");
  await page.evaluate(() => document.dispatchEvent(new Event("turbo:before-cache")));
  assert.equal(await page.locator(previous).isDisabled(), false);
  await waitIndex(page, 0);
  assert.equal(await page.locator(previous).isDisabled(), false);
});

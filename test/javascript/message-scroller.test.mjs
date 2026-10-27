import { browserTest } from "./harness.mjs";
import { assert, settle } from "./support.mjs";

// chadcn--message-scroller (spec: dev/port/specs/message-scroller.md, Behavior). The parity scenarios cannot append rows, so
// streaming, turn anchoring, prepend preservation, scrollToMessage and the events are driven here; ms:<line> cites @shadcn/react 0.3.1.
browserTest.component = "message-scroller";
const viewport = "[data-slot=message-scroller-viewport]";
const content = "[data-slot=message-scroller-content]";
const endButton = "[data-slot=message-scroller-button][data-direction=end]";
const host = "[data-controller~='chadcn--message-scroller']";

const metrics = (page) => page.evaluate((selector) => {
  const el = document.querySelector(selector);
  return { top: el.scrollTop, max: el.scrollHeight - el.clientHeight, height: el.clientHeight };
}, viewport);
const offsetOf = (page, id) => page.evaluate(({ id, selector }) => {
  const row = document.querySelector(`[data-message-id="${id}"]`);
  return row.getBoundingClientRect().top - document.querySelector(selector).getBoundingClientRect().top;
}, { id, selector: viewport });
// Inserts a row at the end (or start) of the content, the way a Turbo Stream append / prepend does.
const addRow = (page, { id, anchor = false, text = "New message", lines = 1, prepend = false }) => page.evaluate(({ id, anchor, text, lines, prepend, selector }) => {
  const row = document.createElement("div");
  row.dataset.slot = "message-scroller-item";
  row.dataset.messageId = id;
  row.dataset.scrollAnchor = String(anchor);
  row.className = "min-w-0 shrink-0";
  row.style.height = `${lines * 40}px`;
  row.textContent = text;
  const list = document.querySelector(selector);
  prepend ? list.prepend(row) : list.querySelector("[data-message-scroller-spacer]").before(row);
}, { id, anchor, text, lines, prepend, selector: content });
// Chrome's own scroll anchoring would also keep a prepend in place; turning it off isolates the controller's restore (ms:211-216).
const withoutNativeAnchoring = (page) => page.evaluate((selector) => { document.querySelector(selector).style.overflowAnchor = "none"; }, viewport);
const nextFrames = (page, count = 3) => page.evaluate((n) => new Promise((resolve) => {
  const tick = (left) => (left === 0 ? setTimeout(resolve, 250) : requestAnimationFrame(() => tick(left - 1)));
  tick(n);
}), count);

browserTest("message-scroller: auto_scroll keeps the viewport at the end while rows stream in (ms:274, ms:276-280)", async ({ open }) => {
  const page = await open("auto-scroll");
  await nextFrames(page);
  for (let index = 0; index < 3; index++) {
    await addRow(page, { id: `s${index}`, lines: 3 });
    await nextFrames(page);
    const { top, max } = await metrics(page);
    assert.ok(Math.abs(top - max) <= 1, `row ${index}: scrollTop ${top} is at the end ${max}`);
  }
  assert.equal(await page.locator(endButton).getAttribute("data-active"), "false", "following the bottom publishes end as false (ms:201)");
});

browserTest("message-scroller: a user scroll up stops following, scrollToEnd resumes it (ms:312-314, ms:163)", async ({ open }) => {
  const page = await open("auto-scroll");
  await nextFrames(page);
  await page.locator(viewport).hover();
  await page.mouse.wheel(0, -400);
  await nextFrames(page);
  const before = await metrics(page);
  assert.ok(before.top < before.max - 50, "the wheel moved the viewport away from the end");
  await addRow(page, { id: "late", lines: 3 });
  await nextFrames(page);
  const after = await metrics(page);
  assert.ok(Math.abs(after.top - before.top) <= 1, "free-scrolling does not follow the new row");
  assert.equal(await page.locator(endButton).getAttribute("data-active"), "true");

  await page.locator(endButton).click();
  await nextFrames(page, 20);
  const end = await metrics(page);
  assert.ok(Math.abs(end.top - end.max) <= 1, "the button scrolled to the end");
  await addRow(page, { id: "after", lines: 3 });
  await nextFrames(page);
  const followed = await metrics(page);
  assert.ok(Math.abs(followed.top - followed.max) <= 1, "scrollToEnd re-engaged follow-output");
});

browserTest("message-scroller: a new scroll_anchor row is anchored below the previous-item peek with a spacer (ms:256-266, ms:148-152)", async ({ open }) => {
  const page = await open("defaults");
  await nextFrames(page);
  await addRow(page, { id: "turn", anchor: true, text: "Question", lines: 1 });
  await nextFrames(page, 20);
  const { top } = await metrics(page);
  const offset = await offsetOf(page, "turn");
  assert.ok(Math.abs(offset - 88) <= 1.5, `the turn sits at padding 24 + peek 64 from the top (was ${offset})`);
  const spacer = page.locator("[data-message-scroller-spacer]");
  assert.equal(await spacer.getAttribute("hidden"), null, "the spacer makes the anchored position reachable");
  assert.match(await spacer.getAttribute("style"), /height: \d+px/);
  assert.ok(top > 0);

  await addRow(page, { id: "reply", lines: 20 });
  await nextFrames(page, 20);
  assert.ok(Math.abs((await offsetOf(page, "turn")) - offset) <= 1.5, "the reply growing below does not move the anchored turn");
});

browserTest("message-scroller: rows prepended above the visible message keep it in place (ms:252-255, ms:211-216)", async ({ open }) => {
  const page = await open("defaults");
  await nextFrames(page);
  await withoutNativeAnchoring(page);
  await page.evaluate((selector) => { document.querySelector(selector).scrollTop = 120; }, viewport);
  await nextFrames(page);
  const visible = await page.evaluate((selector) => {
    const bounds = document.querySelector(selector).getBoundingClientRect();
    return [...document.querySelectorAll("[data-message-id]")].find((row) => {
      const rect = row.getBoundingClientRect();
      return rect.bottom > bounds.top && rect.top < bounds.bottom;
    }).dataset.messageId;
  }, viewport);
  const before = await offsetOf(page, visible);
  await addRow(page, { id: "older", lines: 5, prepend: true });
  await nextFrames(page);
  assert.ok(Math.abs((await offsetOf(page, visible)) - before) <= 1, "the visible message did not move");
});

browserTest("message-scroller: preserve_scroll_on_prepend false lets prepended rows push the content down", async ({ open }) => {
  const page = await open("api__viewport-preserve-scroll-on-prepend-false");
  await nextFrames(page);
  await withoutNativeAnchoring(page);
  await page.evaluate((selector) => { document.querySelector(selector).scrollTop = 120; }, viewport);
  await nextFrames(page);
  const first = await page.evaluate(() => document.querySelector("[data-message-id]").dataset.messageId);
  const before = await offsetOf(page, first);
  await addRow(page, { id: "older", lines: 5, prepend: true });
  await nextFrames(page);
  assert.ok((await offsetOf(page, first)) - before >= 190, "the row was inserted above and the content moved down");
});

browserTest("message-scroller: scrollToMessage scrolls the row to the start, from an action with params (ms:165-176)", async ({ open }) => {
  const page = await open("defaults");
  await nextFrames(page);
  await page.evaluate((selector) => {
    const control = document.createElement("button");
    control.id = "jump";
    control.textContent = "Jump";
    control.dataset.action = "chadcn--message-scroller#scrollToMessage";
    control.dataset["chadcn-MessageScrollerMessageIdParam"] = "m3";
    document.querySelector(selector).append(control);
  }, host);
  await settle(page);
  await page.evaluate(() => { document.querySelector("[data-slot=message-scroller-viewport]").scrollTop = 0; });
  await nextFrames(page);
  await page.click("#jump");
  await nextFrames(page, 10);
  const offset = await offsetOf(page, "m3");
  assert.ok(Math.abs(offset - 24) <= 1.5, `m3 is at the start of the padded viewport (was ${offset})`);
});

browserTest("message-scroller: scrollable-change reports start and end when they change (ms:112-113, ms:192-194)", async ({ open }) => {
  const page = await open("defaults");
  await nextFrames(page);
  await page.evaluate((selector) => {
    window.__scrollable = [];
    document.querySelector(selector).addEventListener("chadcn--message-scroller:scrollable-change", (event) => {
      window.__scrollable.push({ ...event.detail, bubbles: event.bubbles, cancelable: event.cancelable });
    });
    document.querySelector("[data-slot=message-scroller-viewport]").scrollTop = 0;
  }, host);
  await nextFrames(page);
  const events = await page.evaluate(() => window.__scrollable);
  assert.deepEqual(events.map(({ start, end }) => ({ start, end })), [{ start: false, end: true }]);
  assert.equal(events[0].bubbles, true);
  assert.equal(events[0].cancelable, false);
  assert.equal(await page.locator(viewport).getAttribute("data-scrollable"), "end");
  assert.equal(await page.locator("[data-slot=message-scroller]").getAttribute("data-scrollable"), "end");
});

browserTest("message-scroller: visibility-change reports the visible ids and the current anchor with track_visibility (ms:288-303, ms:11-21)", async ({ open }) => {
  const page = await open("position-start");
  await nextFrames(page);
  await page.evaluate((selector) => {
    window.__visibility = [];
    const element = document.querySelector(selector);
    element.addEventListener("chadcn--message-scroller:visibility-change", (event) => window.__visibility.push(event.detail));
    element.setAttribute("data-chadcn--message-scroller-track-visibility-value", "true");
  }, host);
  await nextFrames(page);
  const first = await page.evaluate(() => window.__visibility.at(-1));
  assert.equal(first.currentAnchorId, "m1");
  assert.ok(first.visibleMessageIds.includes("m1") && first.visibleMessageIds.length >= 2, `visible ids ${first.visibleMessageIds}`);

  await page.evaluate((selector) => { document.querySelector(selector).scrollTop = 100000; }, viewport);
  await nextFrames(page);
  const last = await page.evaluate(() => window.__visibility.at(-1));
  const expectedAnchor = await page.evaluate((selector) => {
    const line = document.querySelector(selector).getBoundingClientRect().top + 64 + 0.5;
    return [...document.querySelectorAll("[data-scroll-anchor=true]")].filter((row) => row.getBoundingClientRect().top <= line).at(-1).dataset.messageId;
  }, viewport);
  assert.equal(last.currentAnchorId, expectedAnchor, "the last anchor at or above the peek line (it stays set once scrolled past)");
  assert.notEqual(last.currentAnchorId, "m1");
  assert.ok(last.visibleMessageIds.includes("m8"));
  assert.ok(!last.visibleMessageIds.includes("m1"));

  await page.evaluate((selector) => document.querySelector(selector).setAttribute("data-chadcn--message-scroller-track-visibility-value", "false"), host);
  await nextFrames(page);
  assert.deepEqual(await page.evaluate(() => window.__visibility.at(-1)), { currentAnchorId: null, visibleMessageIds: [] });
});

browserTest("message-scroller: reconnecting the controller is idempotent and leaves no observers behind", async ({ open }) => {
  const page = await open("defaults");
  await nextFrames(page);
  await page.evaluate((selector) => new Promise((resolve) => {
    const element = document.querySelector(selector);
    element.setAttribute("data-controller", "");
    requestAnimationFrame(() => {
      element.setAttribute("data-controller", "chadcn--message-scroller");
      resolve();
    });
  }), host);
  await nextFrames(page);
  const { top, max } = await metrics(page);
  assert.ok(Math.abs(top - max) <= 1, "the opening position is applied again after the reconnect");
  await addRow(page, { id: "extra", anchor: true });
  await nextFrames(page, 10);
  assert.ok(await offsetOf(page, "extra") >= 0, "the content observer works after the reconnect");
});

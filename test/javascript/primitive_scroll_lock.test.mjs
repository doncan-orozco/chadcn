import { assert, primitiveTest } from "./primitives_support.mjs";

// Tall content gives the viewport a classic scrollbar, so the compensation gap is measurable.
const html = '<div style="height: 3000px">tall</div>';
// Headless Chromium hides scrollbars; `scrollbars: true` keeps a classic, measurable one.
const options = { html, scrollbars: true };

const state = () => ({
  attr: document.body.getAttribute("data-scroll-locked"),
  overflow: getComputedStyle(document.body).overflow,
  styles: document.head.querySelectorAll("style").length,
});

primitiveTest("scroll_lock: locking sets data-scroll-locked, hides overflow and compensates the scrollbar; release restores", async (page) => {
  const result = await page.evaluate(async (stateSource) => {
    const { scrollLock } = await import("shadcn/primitives/scroll_lock");
    const read = new Function(`return (${stateSource})()`);
    const before = read();
    const gap = window.innerWidth - document.documentElement.clientWidth;
    const release = scrollLock();
    const locked = { ...read(), marginRight: getComputedStyle(document.body).marginRight, gap };
    release();
    return { before, locked, after: read() };
  }, state.toString());
  assert.equal(result.locked.attr, "1");
  assert.equal(result.locked.overflow, "hidden");
  assert.ok(result.locked.gap > 0, "the page has a classic scrollbar, so the compensation is not vacuous");
  assert.equal(result.locked.marginRight, `${result.locked.gap}px`);
  assert.equal(result.locked.styles, result.before.styles + 1);
  assert.deepEqual(result.after, result.before);
  assert.notEqual(result.before.overflow, "hidden");
}, options);

primitiveTest("scroll_lock: nested locks are counted and only the last release restores the page", async (page) => {
  const result = await page.evaluate(async (stateSource) => {
    const { scrollLock } = await import("shadcn/primitives/scroll_lock");
    const read = new Function(`return (${stateSource})()`);
    const first = scrollLock();
    const second = scrollLock();
    const both = read();
    first();
    const afterFirst = read();
    second();
    return { both, afterFirst, after: read() };
  }, state.toString());
  assert.equal(result.both.attr, "2");
  assert.equal(result.both.styles, result.after.styles + 1);
  assert.equal(result.afterFirst.attr, "1");
  assert.equal(result.afterFirst.overflow, "hidden");
  assert.equal(result.afterFirst.styles, result.both.styles, "the stylesheet is still present after a partial release");
  assert.equal(result.after.attr, null);
  assert.notEqual(result.after.overflow, "hidden");
}, options);

primitiveTest("scroll_lock: a release function is idempotent and cannot unlock someone else's lock", async (page) => {
  const result = await page.evaluate(async () => {
    const { scrollLock } = await import("shadcn/primitives/scroll_lock");
    const first = scrollLock();
    const second = scrollLock();
    first();
    first();
    const stillLocked = document.body.getAttribute("data-scroll-locked");
    second();
    return { stillLocked, after: document.body.getAttribute("data-scroll-locked") };
  });
  assert.deepEqual(result, { stillLocked: "1", after: null });
}, options);

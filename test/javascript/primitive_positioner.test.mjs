import { assert, frames, primitiveTest } from "./primitives_support.mjs";

const html = `
  <button id="anchor" style="position:fixed;left:200px;top:200px;width:100px;height:30px">anchor</button>
  <div id="content" style="width:80px;height:40px;background:#ccc">content<span id="arrow" style="display:block;width:10px;height:5px"></span></div>`;

// Creates the positioner and resolves once the first placement happened.
const place = (options = "{}") => `
  const { positioner } = await import("shadcn/primitives/positioner");
  const anchor = document.getElementById("anchor");
  const content = document.getElementById("content");
  const opts = ${options};
  window.__placed = new Promise((resolve) => { window.__p = positioner(anchor, content, { ...opts, onPlaced: resolve }) });
  await window.__placed;
`;
const run = (page, body) => page.evaluate(new Function(`return (async () => { ${body} })()`));

primitiveTest("positioner: sideAndAlign splits a placement and defaults the align to center", async (page) => {
  const result = await page.evaluate(async () => {
    const { sideAndAlign } = await import("shadcn/primitives/positioner");
    return [sideAndAlign("top"), sideAndAlign("left-start"), sideAndAlign("bottom-end")];
  });
  assert.deepEqual(result, [["top", "center"], ["left", "start"], ["bottom", "end"]]);
});

primitiveTest("positioner: ensureWrapper wraps the content once and reuses an existing wrapper", async (page) => {
  const result = await page.evaluate(async () => {
    const { ensureWrapper } = await import("shadcn/primitives/positioner");
    const content = document.getElementById("content");
    const wrapper = ensureWrapper(content);
    return { wrapped: wrapper.hasAttribute("data-radix-popper-content-wrapper"), parent: content.parentElement === wrapper, again: ensureWrapper(content) === wrapper, wrappers: document.querySelectorAll("[data-radix-popper-content-wrapper]").length };
  });
  assert.deepEqual(result, { wrapped: true, parent: true, again: true, wrappers: 1 });
}, { html });

primitiveTest("positioner: places the content below the anchor, centered, with side offset, data attributes and CSS variables", async (page) => {
  const result = await run(page, `${place("{ sideOffset: 10 }")}
    const r = (el) => { const b = el.getBoundingClientRect(); return { x: b.x, y: b.y } };
    const wrapper = content.parentElement;
    return {
      content: r(content), side: content.dataset.side, align: content.dataset.align,
      anchorSide: anchor.dataset.radixPopperSide, anchorAlign: anchor.dataset.radixPopperAlign,
      position: wrapper.style.position, animation: content.style.animation,
      anchorWidth: wrapper.style.getPropertyValue("--radix-popper-anchor-width"),
      origin: wrapper.style.getPropertyValue("--radix-popper-transform-origin"),
    };`);
  assert.deepEqual(result.content, { x: 210, y: 240 });
  assert.deepEqual([result.side, result.align, result.anchorSide, result.anchorAlign], ["bottom", "center", "bottom", "center"]);
  assert.equal(result.position, "fixed");
  assert.equal(result.animation, "", "the `animation: none` guard is removed once placed");
  assert.equal(result.anchorWidth, "100px");
  assert.equal(result.origin, "50% 0px");
}, { html });

primitiveTest("positioner: honors side, align and alignOffset", async (page) => {
  const result = await run(page, `${place('{ side: "right", align: "start", sideOffset: 4, alignOffset: 6 }')}
    const b = content.getBoundingClientRect();
    return { x: b.x, y: b.y, side: content.dataset.side, align: content.dataset.align };`);
  assert.deepEqual(result, { x: 304, y: 206, side: "right", align: "start" });
}, { html });

primitiveTest("positioner: flips to the opposite side on collision and avoidCollisions: false disables it", async (page) => {
  await page.setViewportSize({ width: 800, height: 260 });
  const flipped = await run(page, `${place("{}")}
    const side = content.dataset.side;
    window.__p.release();
    return side;`);
  assert.equal(flipped, "top");
  const kept = await run(page, `
    const { positioner } = await import("shadcn/primitives/positioner");
    const content = document.getElementById("content");
    const anchor = document.getElementById("anchor");
    const placed = new Promise((resolve) => positioner(anchor, content, { avoidCollisions: false, onPlaced: resolve }));
    await placed;
    return content.dataset.side;`);
  assert.equal(kept, "bottom");
}, { html });

primitiveTest("positioner: update() moves the content to the new side", async (page) => {
  const result = await run(page, `${place("{}")}
    window.__p.update({ side: "top" });
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    const b = content.getBoundingClientRect();
    return { side: content.dataset.side, y: b.y, bottom: b.bottom };`);
  assert.equal(result.side, "top");
  assert.equal(result.bottom, 200);
}, { html });

primitiveTest("positioner: autoUpdate follows an anchor that moves", async (page) => {
  await run(page, place("{}"));
  await page.evaluate(() => { document.getElementById("anchor").style.top = "100px" });
  await frames(page);
  await frames(page);
  const y = await page.evaluate(() => document.getElementById("content").getBoundingClientRect().y);
  assert.equal(y, 130);
}, { html });

primitiveTest("positioner: positions the arrow on the edge facing the anchor", async (page) => {
  const result = await run(page, `${place('{ arrow: document.getElementById("arrow") }')}
    const arrow = document.getElementById("arrow");
    return { position: arrow.style.position, top: arrow.style.top, transform: arrow.style.transform };`);
  assert.equal(result.position, "absolute");
  assert.equal(result.transform, "rotate(180deg)");
  assert.equal(result.top, "0px", "a bottom placement puts the arrow on the top edge, facing the anchor");
}, { html: html.replace('style="width:80px', 'style="position:relative;width:80px') });

primitiveTest("positioner: release() stops tracking and removes the anchor attributes", async (page) => {
  await run(page, place("{}"));
  const before = await page.evaluate(() => document.getElementById("content").getBoundingClientRect().y);
  await page.evaluate(() => {
    window.__p.release();
    window.__p.release();
    document.getElementById("anchor").style.top = "100px";
  });
  await frames(page);
  await frames(page);
  const after = await page.evaluate(() => ({ y: document.getElementById("content").getBoundingClientRect().y, side: document.getElementById("anchor").getAttribute("data-radix-popper-side"), align: document.getElementById("anchor").getAttribute("data-radix-popper-align") }));
  assert.deepEqual(after, { y: before, side: null, align: null });
}, { html });

primitiveTest("positioner: update() after release() does not reposition", async (page) => {
  await run(page, place("{}"));
  const result = await run(page, `
    const wrapper = document.getElementById("content").parentElement;
    window.__p.release();
    const transform = wrapper.style.transform;
    window.__p.update({ side: "top" });
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    return wrapper.style.transform === transform;`);
  assert.equal(result, true);
}, { html });

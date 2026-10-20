import { assert, frames, primitiveTest } from "./primitives_support.mjs";

// The floating element is the positioner itself (Base UI): no wrapper, absolute positioning, the CSS variables on it.
const html = `
  <button id="anchor" style="position:fixed;left:200px;top:200px;width:100px;height:30px">anchor</button>
  <div id="floating" style="width:80px;height:40px;background:#ccc">content</div>`;

const run = (page, body) => page.evaluate(new Function(`return (async () => { ${body} })()`));

// Creates the positioner and resolves once the first placement happened.
const place = (options = "{}") => `
  const { anchorPositioner } = await import("shadcn/primitives/anchor_positioner");
  const anchor = document.getElementById("anchor");
  const floating = document.getElementById("floating");
  const opts = ${options};
  window.__placed = new Promise((resolve) => { window.__p = anchorPositioner(anchor, floating, { ...opts, onPlace: resolve }) });
  await window.__placed;
`;

const rect = `const r = (el) => { const b = el.getBoundingClientRect(); return { x: b.x, y: b.y, width: b.width, height: b.height } };`;

primitiveTest("anchor positioner: stays off the page, invisible and fixed until the first placement", async (page) => {
  const result = await run(page, `
    const { anchorPositioner } = await import("shadcn/primitives/anchor_positioner");
    const floating = document.getElementById("floating");
    const placement = anchorPositioner(document.getElementById("anchor"), floating, {});
    const before = { position: floating.style.position, opacity: floating.style.opacity, width: floating.style.getPropertyValue("--available-width") };
    placement.release();
    return before;`);
  assert.deepEqual(result, { position: "fixed", opacity: "0", width: "100vw" });
}, { html });

primitiveTest("anchor positioner: places the floating element below the anchor with the offset, absolute, with CSS variables and data attributes", async (page) => {
  const result = await run(page, `${place('{ side: "bottom", sideOffset: 6, align: "start" }')}
    ${rect}
    const style = floating.style;
    return {
      box: r(floating), side: floating.dataset.side, align: floating.dataset.align, position: style.position, opacity: style.opacity,
      anchorWidth: style.getPropertyValue("--anchor-width"), anchorHeight: style.getPropertyValue("--anchor-height"),
      origin: style.getPropertyValue("--transform-origin"), hidden: floating.hasAttribute("data-anchor-hidden"),
      wrapped: floating.parentElement === document.body
    };`);
  assert.deepEqual(result.box, { x: 200, y: 236, width: 80, height: 40 });
  assert.deepEqual([result.side, result.align, result.position, result.opacity], ["bottom", "start", "absolute", ""]);
  assert.deepEqual([result.anchorWidth, result.anchorHeight], ["100px", "30px"]);
  assert.equal(result.origin, "0% -6px");
  assert.deepEqual([result.hidden, result.wrapped], [false, true]);
}, { html });

primitiveTest("anchor positioner: a centered placement grows from the middle of the anchor edge", async (page) => {
  const result = await run(page, `${place('{ side: "bottom", sideOffset: 4 }')}
    ${rect}
    return { box: r(floating), origin: floating.style.getPropertyValue("--transform-origin"), align: floating.dataset.align };`);
  assert.deepEqual(result.box, { x: 210, y: 234, width: 80, height: 40 });
  assert.equal(result.align, "center");
  assert.equal(result.origin, "40px -4px");
}, { html });

primitiveTest("anchor positioner: the end alignment, the alignment offset and the other sides", async (page) => {
  const end = await run(page, `${place('{ side: "bottom", align: "end", alignOffset: 5 }')}
    ${rect}
    return { box: r(floating), origin: floating.style.getPropertyValue("--transform-origin") };`);
  assert.deepEqual(end.box, { x: 215, y: 230, width: 80, height: 40 }, "the end alignment offset moves against the reading direction");
  assert.equal(end.origin, "100% 0px");
  const top = await run(page, `${place('{ side: "top", sideOffset: 10, align: "start" }')}
    ${rect}
    return { box: r(floating), side: floating.dataset.side, origin: floating.style.getPropertyValue("--transform-origin") };`);
  assert.deepEqual(top.box, { x: 200, y: 150, width: 80, height: 40 });
  assert.equal(top.side, "top");
  assert.equal(top.origin, "0% calc(100% + 10px)");
  const right = await run(page, `${place('{ side: "right", sideOffset: 4, align: "start" }')}
    ${rect}
    return r(floating);`);
  assert.deepEqual(right, { x: 304, y: 200, width: 80, height: 40 });
}, { html });

primitiveTest("anchor positioner: inline-end follows the direction and data-side keeps the logical name", async (page) => {
  const ltr = await run(page, `${place('{ side: "inline-end", align: "start" }')}
    ${rect}
    return { x: r(floating).x, side: floating.dataset.side };`);
  assert.deepEqual(ltr, { x: 300, side: "inline-end" });
  const rtl = await run(page, `${place('{ side: "inline-end", align: "start", dir: "rtl" }')}
    ${rect}
    return { x: r(floating).x, side: floating.dataset.side };`);
  assert.deepEqual(rtl, { x: 120, side: "inline-end" });
}, { html });

primitiveTest("anchor positioner: flips to the opposite side on collision but never to the other axis", async (page) => {
  await page.setViewportSize({ width: 800, height: 260 });
  const flipped = await run(page, `${place('{ side: "bottom", align: "start" }')}
    const side = floating.dataset.side;
    window.__p.release();
    return side;`);
  assert.equal(flipped, "top");
  await page.setViewportSize({ width: 800, height: 600 });
  await page.evaluate(() => { const a = document.getElementById("anchor"); a.style.left = "0px"; a.style.top = "10px"; a.style.height = "560px"; });
  const kept = await run(page, `${place('{ side: "bottom", align: "start" }')}
    return floating.dataset.side;`);
  assert.equal(kept, "bottom", "no room above or below: it does not move to the side");
}, { html });

primitiveTest("anchor positioner: lazyFlip keeps the side it flipped to while the content grows", async (page) => {
  await page.setViewportSize({ width: 800, height: 330 });
  const result = await run(page, `document.getElementById("floating").style.height = "120px";
    ${place('{ side: "bottom", align: "start", lazyFlip: true }')}
    const first = floating.dataset.side;
    floating.style.height = "10px";
    window.__p.update();
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    return { first, second: floating.dataset.side };`);
  assert.deepEqual(result, { first: "top", second: "top" });
  const eager = await run(page, `
    const { anchorPositioner } = await import("shadcn/primitives/anchor_positioner");
    const floating = document.getElementById("floating");
    floating.style.height = "10px";
    let placed;
    const done = new Promise((resolve) => { placed = anchorPositioner(document.getElementById("anchor"), floating, { side: "bottom", align: "start", onPlace: resolve }) });
    await done;
    const side = floating.dataset.side;
    placed.release();
    return side;`);
  assert.equal(eager, "bottom", "a small content has room below");
}, { html });

primitiveTest("anchor positioner: marks the floating element while the anchor is clipped", async (page) => {
  const result = await run(page, `${place("{}")}
    document.getElementById("anchor").style.top = "-100px";
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    await new Promise((resolve) => setTimeout(resolve, 50));
    return floating.hasAttribute("data-anchor-hidden");`);
  assert.equal(result, true);
}, { html });

primitiveTest("anchor positioner: update() changes the side and autoUpdate follows an anchor that moves", async (page) => {
  const moved = await run(page, `${place('{ side: "bottom", align: "start" }')}
    window.__p.update({ side: "top" });
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    return floating.dataset.side;`);
  assert.equal(moved, "top");
  await page.evaluate(() => { document.getElementById("anchor").style.top = "300px" });
  await frames(page);
  await frames(page);
  const bottom = await page.evaluate(() => document.getElementById("floating").getBoundingClientRect().bottom);
  assert.equal(bottom, 300);
}, { html });

primitiveTest("anchor positioner: onPlace reports every placement and release() stops tracking, idempotently", async (page) => {
  const result = await run(page, `
    const { anchorPositioner } = await import("shadcn/primitives/anchor_positioner");
    const floating = document.getElementById("floating");
    const anchor = document.getElementById("anchor");
    const placements = [];
    const first = new Promise((resolve) => { window.__p = anchorPositioner(anchor, floating, { side: "bottom", align: "start", onPlace: (placed) => { placements.push(placed); resolve() } }) });
    await first;
    const before = floating.getBoundingClientRect().y;
    window.__p.release();
    window.__p.release();
    anchor.style.top = "100px";
    window.__p.update({ side: "top" });
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    return { first: placements[0], unchanged: floating.getBoundingClientRect().y === before, count: placements.length };`);
  assert.deepEqual(result.first, { side: "bottom", align: "start", anchorHidden: false });
  assert.equal(result.unchanged, true);
  assert.equal(result.count, 1);
}, { html });

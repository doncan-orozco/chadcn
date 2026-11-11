import { assert, primitiveTest } from "./primitives_support.mjs";

// DOM reads of the resizable group: sizes, units, hit regions between panels and the stacking-order check, on a hand-built group
// (no controller). Two 200px panels around a 2px separator, the group at the page origin.

const css = "body{margin:0} #g{display:flex;width:402px;height:100px} [data-panel]{flex:0 0 200px} #s{flex:0 0 2px}";
const html = '<div id="g"><div id="a" data-panel></div><div id="s" data-separator></div><div id="b" data-panel></div></div>';

// Defines window.makeAxis in the page: the group record the controller builds.
const defineAxis = (page) => page.evaluate(() => {
  const element = (id) => document.getElementById(id);
  const item = (id, props = {}) => ({
    element: element(id), id, mutableValues: {},
    constraintProps: { groupResizeBehavior: "preserve-relative-size", collapsedSize: "0%", collapsible: false, maxSize: "100%", minSize: "0%", disabled: false, ...props },
  });
  window.makeAxis = (extra = {}) => ({
    element: element("g"), id: "g", orientation: "horizontal", disabled: false, resizePreviewMode: "panel",
    resizeTargetMinimumSize: { coarse: 20, fine: 10 }, mutableState: { disableCursor: false, expandedItemSizes: {}, layouts: {} },
    items: [item("a", { minSize: "50px" }), item("b")], separators: document.getElementById("s") ? [{ element: element("s"), id: "s", disabled: false }] : [],
    ...extra,
  });
});

primitiveTest("resizable_measure: the group size sums its panels, toPixels reads every unit, constraints come out in percent", async (page) => {
  await defineAxis(page);
  const measured = await page.evaluate(async () => {
    const { axisSizeOf, itemPixels, measureConstraints, percentOfAxis, toPixels } = await import("chadcn/primitives/resizable_measure");
    const axis = window.makeAxis();
    const element = axis.items[0].element;
    element.style.fontSize = "10px";
    const px = (value) => toPixels({ axisSize: 400, element, value });
    return {
      axisSize: axisSizeOf(axis), itemPixels: itemPixels(axis, axis.items[1]), percent: percentOfAxis(axis, axis.items[0], "100px"),
      units: [px("25%"), px(30), px("12px"), px("2rem"), px("3em"), px(`${100 * 100 / innerHeight}vh`), px(`${100 * 100 / innerWidth}vw`)].map(Math.round),
      minSizes: measureConstraints(axis).map(({ minSize }) => minSize),
    };
  });
  assert.deepEqual(measured, { axisSize: 400, itemPixels: 200, percent: 25, units: [100, 30, 12, 32, 30, 100, 100], minSizes: [12.5, 0] });
}, { css, html });

primitiveTest("resizable_measure: sortByPosition orders by offset", async (page) => {
  await defineAxis(page);
  const order = await page.evaluate(async () => {
    const { sortByPosition } = await import("chadcn/primitives/resizable_measure");
    return sortByPosition("horizontal", [...window.makeAxis().items].reverse()).map(({ id }) => id);
  });
  assert.deepEqual(order, ["a", "b"]);
}, { css, html });

primitiveTest("resizable_measure: sortByPosition falls back to document order for entries at the same offset and size", async (page) => {
  await page.evaluate(() => {
    document.body.insertAdjacentHTML("beforeend", '<div id="tie"><span id="first" style="display:inline-block;width:0;height:10px"></span><span id="second" style="display:inline-block;width:0;height:10px"></span></div>');
  });
  const order = await page.evaluate(async () => {
    const { sortByPosition } = await import("chadcn/primitives/resizable_measure");
    const entry = (id) => ({ id, element: document.getElementById(id) });
    const sorted = (orientation) => sortByPosition(orientation, [entry("second"), entry("first")]).map(({ id }) => id);
    return { horizontal: sorted("horizontal"), vertical: sorted("vertical"), offsets: [document.getElementById("first").offsetLeft, document.getElementById("second").offsetLeft] };
  });
  assert.deepEqual(order, { horizontal: ["first", "second"], vertical: ["first", "second"], offsets: [0, 0] });
}, { css, html });

primitiveTest("resizable_measure: a hit region sits on its separator, expanded to the minimum target size", async (page) => {
  await defineAxis(page);
  const regions = await page.evaluate(async () => {
    const { hitRegionsOf } = await import("chadcn/primitives/resizable_measure");
    const axis = window.makeAxis();
    const [region] = hitRegionsOf({ axis });
    return {
      count: hitRegionsOf({ axis }).length, separator: region.separator.id, items: region.items.map(({ id }) => id), left: region.rect.left,
      width: region.rect.width, axisSize: region.axisSize, unexpanded: hitRegionsOf({ axis, expandHitTargets: false })[0].rect.width,
    };
  });
  assert.deepEqual(regions, { count: 1, separator: "s", items: ["a", "b"], left: 196, width: 10, axisSize: 400, unexpanded: 2 });
}, { css, html });

primitiveTest("resizable_measure: without a separator the hit region is the gap between two panels", async (page) => {
  await defineAxis(page);
  const gap = await page.evaluate(async () => {
    const { hitRegionsOf } = await import("chadcn/primitives/resizable_measure");
    document.getElementById("s").remove();
    const [region] = hitRegionsOf({ axis: window.makeAxis() });
    return { separator: region.separator ?? null, left: region.rect.left, width: region.rect.width };
  });
  assert.deepEqual(gap, { separator: null, left: 195, width: 10 });
}, { css, html });

primitiveTest("resizable_measure: a hit region next to a disabled panel is skipped unless disabled regions are included", async (page) => {
  await defineAxis(page);
  const counts = await page.evaluate(async () => {
    const { hitRegionsOf } = await import("chadcn/primitives/resizable_measure");
    const enabled = hitRegionsOf({ axis: window.makeAxis() }).length;
    document.getElementById("b").setAttribute("data-disabled", "");
    return { enabled, disabled: hitRegionsOf({ axis: window.makeAxis() }).length, included: hitRegionsOf({ axis: window.makeAxis(), includeDisabled: true }).length };
  });
  assert.deepEqual(counts, { enabled: 1, disabled: 0, included: 1 });
}, { css, html });

primitiveTest("resizable_measure: pointerHits finds the separator under the pointer and skips disabled groups", async (page) => {
  await defineAxis(page);
  const hits = await page.evaluate(async () => {
    const { pointerHits } = await import("chadcn/primitives/resizable_measure");
    const axis = window.makeAxis();
    const separator = document.getElementById("s");
    const hitsAt = (x, axes = new Map([[axis, {}]])) => pointerHits({ clientX: x, clientY: 50, target: separator }, axes).map((hit) => hit.separator?.id);
    return {
      on: hitsAt(201), edge: hitsAt(197), off: hitsAt(150),
      disabled: hitsAt(201, new Map([[window.makeAxis({ disabled: true }), {}]])),
    };
  });
  assert.deepEqual(hits, { on: ["s"], edge: ["s"], off: [], disabled: [] });
}, { css, html });

primitiveTest("resizable_measure: pointerHits skips a region another element covers, and isReachable tells covered from clear", async (page) => {
  await defineAxis(page);
  const reach = await page.evaluate(async () => {
    const { compareStacking, isReachable, pointerHits } = await import("chadcn/primitives/resizable_measure");
    const axis = window.makeAxis();
    const cover = Object.assign(document.createElement("div"), { id: "cover" });
    Object.assign(cover.style, { position: "fixed", left: "190px", top: "0", width: "30px", height: "100px", zIndex: "10" });
    document.body.append(cover);
    const reachable = (hitRegion) => isReachable({ axisElement: axis.element, hitRegion, pointerEventTarget: cover });
    return {
      hitsUnderCover: pointerHits({ clientX: 201, clientY: 50, target: cover }, new Map([[axis, {}]])).map((hit) => hit.separator?.id),
      clearRegion: reachable({ x: 300, y: 0, width: 10, height: 100 }),
      coveredRegion: reachable({ x: 196, y: 0, width: 10, height: 100 }),
      below: compareStacking(axis.element, cover),
      above: compareStacking(cover, axis.element),
    };
  });
  assert.deepEqual(reach, { hitsUnderCover: [], clearRegion: true, coveredRegion: false, below: -1, above: 1 });
}, { css, html });

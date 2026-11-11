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
  const result = await page.evaluate(async () => {
    const M = await import("chadcn/primitives/resizable_measure");
    const axis = window.makeAxis();
    const element = axis.items[0].element;
    element.style.fontSize = "10px";
    const px = (value) => M.toPixels({ axisSize: 400, element, value });
    return {
      axisSize: M.axisSizeOf(axis), itemPixels: M.itemPixels(axis, axis.items[1]), percent: M.percentOfAxis(axis, axis.items[0], "100px"),
      units: [px("25%"), px(30), px("12px"), px("2rem"), px("3em"), px(`${100 * 100 / innerHeight}vh`), px(`${100 * 100 / innerWidth}vw`)].map(Math.round),
      minSizes: M.measureConstraints(axis).map(({ minSize }) => minSize),
    };
  });
  assert.deepEqual(result, { axisSize: 400, itemPixels: 200, percent: 25, units: [100, 30, 12, 32, 30, 100, 100], minSizes: [12.5, 0] });
}, { css, html });

primitiveTest("resizable_measure: sortByPosition orders by offset then document order; hit regions sit on separators or between panels", async (page) => {
  await defineAxis(page);
  const result = await page.evaluate(async () => {
    const M = await import("chadcn/primitives/resizable_measure");
    const axis = window.makeAxis();
    const reversed = M.sortByPosition("horizontal", [...axis.items].reverse()).map(({ id }) => id);
    const [region] = M.hitRegionsOf({ axis });
    const separated = { count: M.hitRegionsOf({ axis }).length, separator: region.separator.id, items: region.items.map(({ id }) => id), left: region.rect.left, width: region.rect.width, axisSize: region.axisSize };
    const unexpanded = M.hitRegionsOf({ axis, expandHitTargets: false })[0].rect.width;
    document.getElementById("s").remove();
    const [gap] = M.hitRegionsOf({ axis: window.makeAxis() });
    document.getElementById("b").setAttribute("data-disabled", "");
    const disabled = [M.hitRegionsOf({ axis: window.makeAxis() }).length, M.hitRegionsOf({ axis: window.makeAxis(), includeDisabled: true }).length];
    return { reversed, separated, unexpanded, gap: { separator: gap.separator ?? null, left: gap.rect.left, width: gap.rect.width }, disabled };
  });
  assert.deepEqual(result, {
    reversed: ["a", "b"],
    separated: { count: 1, separator: "s", items: ["a", "b"], left: 196, width: 10, axisSize: 400 },
    unexpanded: 2,
    gap: { separator: null, left: 195, width: 10 },
    disabled: [0, 1],
  });
}, { css, html });

primitiveTest("resizable_measure: pointerHits finds the separator under the pointer, skips disabled groups and covered regions", async (page) => {
  await defineAxis(page);
  const result = await page.evaluate(async () => {
    const M = await import("chadcn/primitives/resizable_measure");
    const axis = window.makeAxis();
    const hits = (target, x, axes = new Map([[axis, {}]])) => M.pointerHits({ clientX: x, clientY: 50, target }, axes).map((hit) => hit.separator?.id);
    const separator = document.getElementById("s");
    const result = {
      on: hits(separator, 201), edge: hits(separator, 197), off: hits(separator, 150),
      disabled: hits(separator, 201, new Map([[window.makeAxis({ disabled: true }), {}]])),
    };
    const cover = Object.assign(document.createElement("div"), { id: "cover" });
    Object.assign(cover.style, { position: "fixed", left: "190px", top: "0", width: "30px", height: "100px", zIndex: "10" });
    document.body.append(cover);
    result.covered = hits(cover, 201);
    result.reachable = M.isReachable({ axisElement: axis.element, hitRegion: { x: 300, y: 0, width: 10, height: 100 }, pointerEventTarget: cover });
    result.below = M.compareStacking(axis.element, cover);
    return result;
  });
  assert.deepEqual(result, { on: ["s"], edge: ["s"], off: [], disabled: [], covered: [], reachable: true, below: -1 });
}, { css, html });
